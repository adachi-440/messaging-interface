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
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

contract CrossChainRouter is
    Ownable,
    ICrossChainRouter,
    IMessageRecipient,
    IXReceiver,
    ILayerZeroReceiver
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

    // receiver address(chainId => receiver address)
    mapping(uint32 => address) private receivers;
    mapping(uint16 => bytes) public trustedRemoteLookup;
    mapping(uint32 => mapping(uint32 => address)) inboxes;

    event SetTrustedRemote(uint16 _remoteChainId, bytes _path);

    constructor(
        address _connext,
        address _outbox,
        address _gasPaymaster,
        address _layerZero
    ) {
        connext = _connext;
        outbox = _outbox;
        gasPaymaster = _gasPaymaster;
        layerZero = _layerZero;
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
        address receiver = receivers[dstChainId];

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
        bytes memory trustedRemote = trustedRemoteLookup[destinationDomain];
        require(
            trustedRemote.length != 0,
            "Cross Chain Router: destination chain is not a trusted source"
        );
        ILayerZeroEndpoint(layerZero).send{value: relayerFee}(
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
    ) internal {}

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
        bytes memory trustedRemote = trustedRemoteLookup[_srcChainId];
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
            convertChainIdToLayerZeroDomain(_srcChainId),
            fromAddress,
            callData
        );
    }

    function setReceiver(
        address _receiver,
        uint32 _chainId
    ) external onlyOwner {
        receivers[_chainId] = _receiver;
    }

    function getReceiver(uint32 _chainId) external view returns (address) {
        return receivers[_chainId];
    }

    function setTrustedRemote(
        uint16 _srcChainId,
        bytes calldata _path
    ) external onlyOwner {
        trustedRemoteLookup[_srcChainId] = _path;
        emit SetTrustedRemote(_srcChainId, _path);
    }

    function getTrustedRemoteAddress(
        uint16 _remoteChainId
    ) external view returns (bytes memory) {
        bytes memory path = trustedRemoteLookup[
            convertChainIdToLayerZeroDomain(_remoteChainId)
        ];
        require(path.length != 0, "Cross Chain Router: no trusted path record");
        return path.slice(0, path.length - 20); // the last 20 bytes should be address(this)
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function convertChainIdToHyperlaneDomain(
        uint32 _dstChainId
    ) internal pure returns (uint32) {
        if (_dstChainId == 5) {
            return _dstChainId;
        } else if (_dstChainId == 80001) {
            return _dstChainId;
        } else if (_dstChainId == 1287) {
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
        } else {
            return uint16(_dstChainId);
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
        if (_domain == 5) {
            return _domain;
        } else if (_domain == 80001) {
            return _domain;
        } else if (_domain == 0x6d6f2d61) {
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
        } else {
            return _domain;
        }
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
}
