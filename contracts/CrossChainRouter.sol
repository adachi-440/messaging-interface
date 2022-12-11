// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./interfaces/ICrossChainRouter.sol";
import "./interfaces/IOutbox.sol";
import "./interfaces/IInterchainGasPaymaster.sol";
import "./interfaces/ILayerZeroEndpoint.sol";
import "./util/BytesLib.sol";
import "./interfaces/IMessageRecipient.sol";
import "./interfaces/IReceiver.sol";
import "./interfaces/ILayerZeroReceiver.sol";
import {IXReceiver} from "@connext/nxtp-contracts/contracts/core/connext/interfaces/IXReceiver.sol";
import "@connext/nxtp-contracts/contracts/core/connext/interfaces/IConnext.sol";
import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executables/AxelarExecutable.sol";
import {IAxelarGateway} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "hardhat/console.sol";

contract CrossChainRouter is
    Ownable,
    ICrossChainRouter,
    IMessageRecipient,
    IXReceiver,
    ILayerZeroReceiver,
    AxelarExecutable
{
    using BytesLib for bytes;

    address public constant CONNEXT_ASSET_FOR_NONE = address(0x0);
    uint256 public constant CONNEXT_AMOUNT_FOR_NONE = 0;

    // connext address
    address public immutable connext;

    // hyperlane address
    address public immutable outbox;
    address public immutable gasPaymaster;

    address public immutable layerZero;

    // Axelar
    address public immutable gasReceiver;

    // receiver address(chainId => receiver address)
    mapping(uint32 => bytes) public trustedRemoteLookup;
    mapping(uint32 => mapping(uint32 => address)) inboxes;

    event SetTrustedRemote(uint32 _remoteChainId, bytes _path);

    constructor(
        address _connext,
        address _outbox,
        address _gasPaymaster,
        address _layerZero,
        address _gateway,
        address _gasReceiver
    ) AxelarExecutable(_gateway) {
        connext = _connext;
        outbox = _outbox;
        gasPaymaster = _gasPaymaster;
        layerZero = _layerZero;
        gasReceiver = _gasReceiver;
    }

    //---------------------------Send function----------------------------------------

    function sendMessage(
        uint32 protocolId,
        uint32 dstChainId,
        uint256 relayerFee,
        address user,
        bytes memory callData
    ) external payable {
        bytes memory data = encodeReceiver(callData, user);
        address receiver = getTrustedRemoteAddress(dstChainId);

        /*
          protocolId
          1. hyperlane
          2. Connext
          3. LayerZero
          4. Axelar
        */

        if (protocolId == 1) {
            require(
                outbox != address(0x0),
                "CrossChainRouter: Hyperlane does not support this chain"
            );
            _sendByHyperlane(dstChainId, data, receiver);
        } else if (protocolId == 2) {
            require(
                connext != address(0x0),
                "CrossChainRouter: Connext does not support this chain"
            );
            _sendByConnext(dstChainId, relayerFee, data, receiver);
        } else if (protocolId == 3) {
            require(
                layerZero != address(0x0),
                "CrossChainRouter: LayerZero does not support this chain"
            );
            _sendByLayerZero(dstChainId, relayerFee, data);
        } else if (protocolId == 4) {
            require(
                gasReceiver != address(0x0),
                "CrossChainRouter: Axelar does not support this chain"
            );
            _sendByAxelar(dstChainId, relayerFee, data, receiver);
        }
    }

    function _sendByHyperlane(
        uint32 dstChainId,
        bytes memory callData,
        address receiver
    ) internal {
        bytes32 recipient = addressToBytes32(receiver);
        uint32 destinationDomain = convertChainIdToHyperlaneDomain(dstChainId);
        IOutbox(outbox).dispatch(destinationDomain, recipient, callData);
    }

    function _sendByConnext(
        uint32 dstChainId,
        uint256 relayerFee,
        bytes memory callData,
        address receiver
    ) internal {
        uint32 destinationDomain = convertChainIdToConnextDomain(dstChainId);
        IConnext(connext).xcall{value: relayerFee}(
            destinationDomain,
            receiver,
            CONNEXT_ASSET_FOR_NONE,
            msg.sender,
            CONNEXT_AMOUNT_FOR_NONE,
            CONNEXT_AMOUNT_FOR_NONE,
            callData
        );
    }

    function _sendByLayerZero(
        uint32 dstChainId,
        uint256 relayerFee,
        bytes memory callData
    ) internal {
        uint16 destinationDomain = convertChainIdToLayerZeroDomain(dstChainId);
        bytes memory trustedRemote = trustedRemoteLookup[dstChainId];
        require(
            trustedRemote.length != 0,
            "Cross Chain Router: destination chain is not a trusted source"
        );
        ILayerZeroEndpoint(layerZero).send{value: msg.value}(
            destinationDomain, // destination LayerZero chainId
            trustedRemote, // send to this address on the destination
            callData, // bytes payload
            payable(_msgSender()), // refund address
            address(0x0), // future parameter
            bytes("") // adapterParams (see "Advanced Features")
        );
    }

    function _sendByAxelar(
        uint32 dstChainId,
        uint256 relayerFee,
        bytes memory callData,
        address receiver
    ) internal {
        string memory destinationChain = convertChainIdToName(dstChainId);
        string memory destinationAddress = Strings.toHexString(
            uint160(receiver),
            20
        );
        if (relayerFee > 0) {
            console.log(relayerFee);
            console.log(msg.value);
            console.log(gasReceiver);
            IAxelarGasService(gasReceiver).payNativeGasForContractCall{
                value: msg.value
            }(
                address(this),
                destinationChain,
                destinationAddress,
                callData,
                _msgSender()
            );
        }
        gateway.callContract(destinationChain, destinationAddress, callData);
    }

    //---------------------------Receive function----------------------------------------

    // Hyperlane
    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes memory _message
    ) external {
        // format data
        address sender = bytes32ToAddress(_sender);
        (address receiver, bytes memory callData) = decodeReceiver(_message);
        IReceiver(receiver).receiveMessage(
            _sender,
            convertHyperlaneDomainToChainId(_origin),
            sender,
            callData
        );
    }

    // Connext
    function xReceive(
        bytes32 _transferId,
        uint256 _amount,
        address _asset,
        address _originSender,
        uint32 _origin,
        bytes memory _callData
    ) external returns (bytes memory) {
        // format data
        (address receiver, bytes memory callData) = decodeReceiver(_callData);
        IReceiver(receiver).receiveMessage(
            _transferId,
            convertConnextDomainToChainId(_origin),
            _originSender,
            callData
        );
    }

    // LayerZero
    function lzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) external override {
        require(
            _msgSender() == address(layerZero),
            "Cross Chain Router: invalid endpoint caller"
        );
        uint32 srcDomain = convertLayerZeroDomainToChainId(_srcChainId);
        bytes memory trustedRemote = trustedRemoteLookup[srcDomain];
        require(
            _srcAddress.length == trustedRemote.length &&
                trustedRemote.length > 0 &&
                keccak256(_srcAddress) == keccak256(trustedRemote),
            "Cross Chain Router: invalid source sending contract"
        );

        (address receiver, bytes memory callData) = decodeReceiver(_payload);
        address fromAddress;
        assembly {
            fromAddress := mload(add(_srcAddress, 20))
        }
        IReceiver(receiver).receiveMessage(
            bytes32(""),
            srcDomain,
            fromAddress,
            callData
        );
    }

    // Axelar
    function _execute(
        string calldata _sourceChain,
        string calldata _sourceAddress,
        bytes calldata _payload
    ) internal override {
        uint32 srcChainId = convertNameToChainId(_sourceChain);
        (address receiver, bytes memory callData) = decodeReceiver(_payload);
        bytes memory trustedRemote = trustedRemoteLookup[srcChainId];

        address fromAddress;
        assembly {
            fromAddress := mload(add(trustedRemote, 20))
        }

        IReceiver(receiver).receiveMessage(
            bytes32(""),
            srcChainId,
            fromAddress,
            callData
        );
    }

    //---------------------------Helper function----------------------------------------

    function setTrustedRemote(
        uint32 _srcChainId,
        bytes calldata _path
    ) external onlyOwner {
        trustedRemoteLookup[
            convertLayerZeroDomainToChainId(_srcChainId)
        ] = _path;
        emit SetTrustedRemote(_srcChainId, _path);
    }

    function getTrustedRemoteAddress(
        uint32 _remoteChainId
    ) public view returns (address) {
        bytes memory path = trustedRemoteLookup[_remoteChainId];
        require(path.length != 0, "Cross Chain Router: no trusted path record");
        bytes memory remoteAddress = path.slice(0, path.length - 20); // the last 20 bytes should be address(this)
        address addr;
        assembly {
            addr := mload(add(remoteAddress, 20))
        }
        return addr;
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function convertChainIdToHyperlaneDomain(
        uint32 _dstChainId
    ) internal pure returns (uint32) {
        if (_dstChainId == 1287) {
            return 0x6d6f2d61;
        } else {
            return _dstChainId;
        }
    }

    function convertChainIdToConnextDomain(
        uint32 _dstChainId
    ) internal pure returns (uint32) {
        if (_dstChainId == 5) {
            return 1735353714;
        } else if (_dstChainId == 80001) {
            return 9991;
        } else if (_dstChainId == 420) {
            return 1735356532;
        } else {
            return _dstChainId;
        }
    }

    function convertChainIdToLayerZeroDomain(
        uint32 _dstChainId
    ) internal pure returns (uint16) {
        if (_dstChainId == 1287) {
            return 10126;
        } else if (_dstChainId == 420) {
            return 10132;
        } else if (_dstChainId == 421613) {
            return 10143;
        } else if (_dstChainId == 80001) {
            return 10109;
        } else {
            return uint16(_dstChainId);
        }
    }

    function convertChainIdToName(
        uint32 _dstChainId
    ) internal pure returns (string memory) {
        if (_dstChainId == 1287) {
            return "Moonbeam";
        } else if (_dstChainId == 421613) {
            return "arbitrum";
        } else if (_dstChainId == 80001) {
            return "Polygon";
        } else {
            return "";
        }
    }

    function encodeReceiver(
        bytes memory callData,
        address user
    ) internal pure returns (bytes memory) {
        bytes memory data = abi.encode(user, callData);
        return data;
    }

    function bytes32ToAddress(bytes32 _buf) internal pure returns (address) {
        return address(uint160(uint256(_buf)));
    }

    function convertHyperlaneDomainToChainId(
        uint32 _domain
    ) internal pure returns (uint32) {
        if (_domain == 0x6d6f2d61) {
            return 1287;
        } else {
            return _domain;
        }
    }

    function convertConnextDomainToChainId(
        uint32 _domain
    ) internal pure returns (uint32) {
        if (_domain == 1735353714) {
            return 5;
        } else if (_domain == 9991) {
            return 80001;
        } else if (_domain == 1735356532) {
            return 420;
        } else {
            return _domain;
        }
    }

    function convertLayerZeroDomainToChainId(
        uint32 _domain
    ) internal pure returns (uint32) {
        if (_domain == 10126) {
            return 1287;
        } else if (_domain == 10132) {
            return 420;
        } else if (_domain == 10143) {
            return 421613;
        } else if (_domain == 10109) {
            return 80001;
        } else {
            return _domain;
        }
    }

    function convertNameToChainId(
        string memory name
    ) internal pure returns (uint32) {
        if (compare(name, "Moonbeam")) {
            return 1287;
        } else if (compare(name, "arbitrum")) {
            return 421613;
        } else if (compare(name, "Polygon")) {
            return 80001;
        } else {
            return 0;
        }
    }

    function compare(
        string memory str1,
        string memory str2
    ) internal pure returns (bool) {
        if (bytes(str1).length != bytes(str2).length) {
            return false;
        }
        return
            keccak256(abi.encodePacked(str1)) ==
            keccak256(abi.encodePacked(str2));
    }

    function decodeReceiver(
        bytes memory callData
    ) internal pure returns (address, bytes memory) {
        (address receiver, bytes memory data) = abi.decode(
            callData,
            (address, bytes)
        );
        return (receiver, data);
    }

    // test
    function getStringAddress(address adr) public pure returns (string memory) {
        string memory destinationAddress = Strings.toHexString(
            uint160(adr),
            20
        );

        return destinationAddress;
    }

    function estimateSendFee(
        uint16 _dstChainId,
        bytes memory payload,
        bool _useZro
    ) public view returns (uint nativeFee, uint zroFee) {
        // mock the payload for sendFrom()
        return
            ILayerZeroEndpoint(layerZero).estimateFees(
                _dstChainId,
                address(this),
                payload,
                _useZro,
                bytes("")
            );
    }
}
