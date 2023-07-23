// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//////////////////////////////////////////////////////////////////////////////////////
// @title   Peanut Protocol
// @notice  This contract is used to send non front-runnable link payments. These can
//          be erc20, erc721, erc1155 or just plain eth. The recipient address is arbitrary.
//          Links use asymmetric ECDSA encryption by default to be secure & enable trustless,
//          gasless claiming.
//          more at: https://peanut.to
// @version 0.4
// @author  H & K
//////////////////////////////////////////////////////////////////////////////////////
//⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
//                         ⠀⠀⢀⣀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣶⣶⣦⣌⠙⠋⢡⣴⣶⡄⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⣿⣿⣿⡿⢋⣠⣶⣶⡌⠻⣿⠟⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⡆⠸⠟⢁⣴⣿⣿⣿⣿⣿⡦⠉⣴⡇⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣾⣿⠟⠀⠰⣿⣿⣿⣿⣿⣿⠟⣠⡄⠹⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡀⢸⡿⢋⣤⣿⣄⠙⣿⣿⡿⠟⣡⣾⣿⣿⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⣠⣴⣾⠿⠀⢠⣾⣿⣿⣿⣦⠈⠉⢠⣾⣿⣿⣿⠏⠀⠀⠀
// ⠀⠀⠀⠀⣀⣤⣦⣄⠙⠋⣠⣴⣿⣿⣿⣿⠿⠛⢁⣴⣦⡄⠙⠛⠋⠁⠀⠀⠀⠀
// ⠀⠀⢀⣾⣿⣿⠟⢁⣴⣦⡈⠻⣿⣿⡿⠁⡀⠚⠛⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠘⣿⠟⢁⣴⣿⣿⣿⣿⣦⡈⠛⢁⣼⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⢰⡦⠀⢴⣿⣿⣿⣿⣿⣿⣿⠟⢀⠘⠿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠘⢀⣶⡀⠻⣿⣿⣿⣿⡿⠋⣠⣿⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⢿⣿⣿⣦⡈⠻⣿⠟⢁⣼⣿⣿⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠈⠻⣿⣿⣿⠖⢀⠐⠿⠟⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠈⠉⠁⠀⠀⠀⠀⠀
//
//////////////////////////////////////////////////////////////////////////////////////

// imports
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

contract PeanutV4 is IERC721Receiver, IERC1155Receiver, ReentrancyGuard {
    struct deposit {
        address pubKey20; // last 20 bytes of the hash of the public key for the deposit
        uint256 amount; // amount of the asset being sent
        address tokenAddress; // address of the asset being sent. 0x0 for eth
        uint8 contractType; // 0 for eth, 1 for erc20, 2 for erc721, 3 for erc1155
        uint256 tokenId; // id of the token being sent (if erc721 or erc1155)
        address senderAddress; // address of the sender
        uint256 timestamp; // timestamp of the deposit
        // TODO: Can also potentially add link time expiry here. Future approach.
    }

    deposit[] public deposits; // array of deposits

    // events
    event DepositEvent(
        uint256 _index,
        uint8 _contractType,
        uint256 _amount,
        address indexed _senderAddress
    );
    event BatchDepositEvent(
        uint256[] _indexes,
        uint8[] _contractTypes,
        uint256[] _amounts,
        address indexed _senderAddress
    );
    event WithdrawEvent(
        uint256 _index,
        uint8 _contractType,
        uint256 _amount,
        address indexed _recipientAddress
    );
    event MessageEvent(string message);

    // constructor
    constructor() {
        emit MessageEvent("Hello World, have a nutty day!");
    }

    /**
        @notice supportsInterface function
        @dev ERC165 interface detection
        @param _interfaceId bytes4 the interface identifier, as specified in ERC-165
        @return bool true if the contract implements the interface specified in _interfaceId
     */
    function supportsInterface(
        bytes4 _interfaceId
    ) external pure override returns (bool) {
        return
            _interfaceId == type(IERC165).interfaceId ||
            _interfaceId == type(IERC721Receiver).interfaceId ||
            _interfaceId == type(IERC1155Receiver).interfaceId;
    }

    /**
     * @notice Function to make a deposit
     * @dev For token deposits, allowance must be set before calling this function
     * @param _tokenAddress address of the token being sent. 0x0 for eth
     * @param _contractType uint8 for the type of contract being sent. 0 for eth, 1 for erc20, 2 for erc721, 3 for erc1155
     * @param _amount uint256 of the amount of tokens being sent (if erc20)
     * @param _tokenId uint256 of the id of the token being sent if erc721 or erc1155
     * @param _pubKey20 last 20 bytes of the public key of the deposit signer
     * @return uint256 index of the deposit
     */
    function makeDeposit(
        address _tokenAddress,
        uint8 _contractType,
        uint256 _amount,
        uint256 _tokenId,
        address _pubKey20
    ) public payable nonReentrant returns (uint256) {
        // check that the contract type is valid
        require(_contractType < 4, "INVALID CONTRACT TYPE");

        // handle deposit types
        if (_contractType == 0) {
            // check that the amount sent is equal to the amount being deposited
            require(msg.value > 0, "NO ETH SENT");
            // override amount with msg.value
            _amount = msg.value;
        } else if (_contractType == 1) {
            // REMINDER: User must approve this contract to spend the tokens before calling this function
            // Unfortunately there's no way of doing this in just one transaction.
            // Wallet abstraction pls

            IERC20 token = IERC20(_tokenAddress);

            // require users token balance to be greater than or equal to the amount being deposited
            require(
                token.balanceOf(msg.sender) >= _amount,
                "INSUFFICIENT TOKEN BALANCE"
            );

            // require allowance to be at least the amount being deposited
            require(
                token.allowance(msg.sender, address(this)) >= _amount,
                "INSUFFICIENT ALLOWANCE"
            );

            // transfer the tokens to the contract
            require(
                token.transferFrom(msg.sender, address(this), _amount),
                "TRANSFER FAILED. CHECK ALLOWANCE & BALANCE"
            );
        } else if (_contractType == 2) {
            // REMINDER: User must approve this contract to spend the tokens before calling this function.
            // alternatively, the user can call the safeTransferFrom function directly and append the appropriate calldata

            IERC721 token = IERC721(_tokenAddress);
            // require(token.ownerOf(_tokenId) == msg.sender, "Invalid token id");
            token.safeTransferFrom(
                msg.sender,
                address(this),
                _tokenId,
                "Internal transfer"
            );
        } else if (_contractType == 3) {
            // REMINDER: User must approve this contract to spend the tokens before calling this function.
            // alternatively, the user can call the safeTransferFrom function directly and append the appropriate calldata

            IERC1155 token = IERC1155(_tokenAddress);
            token.safeTransferFrom(
                msg.sender,
                address(this),
                _tokenId,
                _amount,
                "Internal transfer"
            );
        }

        // create deposit
        deposits.push(
            deposit({
                tokenAddress: _tokenAddress,
                contractType: _contractType,
                amount: _amount,
                tokenId: _tokenId,
                pubKey20: _pubKey20,
                senderAddress: msg.sender,
                timestamp: block.timestamp
            })
        );

        // emit the deposit event
        emit DepositEvent(
            deposits.length - 1,
            _contractType,
            _amount,
            msg.sender
        );

        // return id of new deposit
        return deposits.length - 1;
    }

    /**
     * @notice This is an absolute gas nightmare, please don't let CT see this
     */
    function batchMakeDeposit(
        address[] calldata _tokenAddresses,
        uint8[] calldata _contractTypes,
        uint256[] calldata _amounts,
        uint256[] calldata _tokenIds,
        address[] calldata _pubKeys20
    ) external payable returns (uint256[] memory) {
        require(
            _tokenAddresses.length == _contractTypes.length &&
                _contractTypes.length == _amounts.length &&
                _amounts.length == _tokenIds.length &&
                _tokenIds.length == _pubKeys20.length,
            "PARAMETERS LENGTH MISMATCH"
        );

        uint256[] memory depositIndexes = new uint256[](_tokenAddresses.length);

        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            depositIndexes[i] = makeDeposit(
                _tokenAddresses[i],
                _contractTypes[i],
                _amounts[i],
                _tokenIds[i],
                _pubKeys20[i]
            );
        }

        return depositIndexes;
    }

    /**
     * @notice Batch ether deposit. Slightly better for gas, still bad.
     * @param _amounts uint256 array of the amounts of ether being sent
     * @param _pubKeys20 array of the last 20 bytes of the public keys of the deposit signers
     * @return uint256[] array of indices of the deposits
     */
    function batchMakeDepositEther(
        uint256[] calldata _amounts,
        address[] calldata _pubKeys20
    ) external payable returns (uint256[] memory) {
        require(
            _amounts.length == _pubKeys20.length,
            "PARAMETERS LENGTH MISMATCH"
        );

        uint256[] memory depositIndexes = new uint256[](_amounts.length);
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < _amounts.length; i++) {
            depositIndexes[i] = makeDeposit(
                address(0),
                0,
                _amounts[i],
                0,
                _pubKeys20[i]
            );
            totalAmount += _amounts[i];
        }

        require(msg.value == totalAmount, "INVALID TOTAL ETHER SENT");

        return depositIndexes;
    }

    function batchMakeDepositEtherOptimized(
        uint256[] calldata _amounts,
        address[] calldata _pubKeys20
    ) external payable returns (uint256[] memory) {
        require(
            _amounts.length == _pubKeys20.length,
            "PARAMETERS LENGTH MISMATCH"
        );

        uint256[] memory depositIndexes = new uint256[](_amounts.length);
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];

            deposits.push(
                deposit({
                    tokenAddress: address(0),
                    contractType: 0,
                    amount: _amounts[i],
                    tokenId: 0,
                    pubKey20: _pubKeys20[i],
                    senderAddress: msg.sender,
                    timestamp: block.timestamp
                })
            );

            depositIndexes[i] = deposits.length - 1;

            emit DepositEvent(depositIndexes[i], 0, _amounts[i], msg.sender);
        }

        require(msg.value == totalAmount, "INVALID TOTAL ETHER SENT");

        return depositIndexes;
    }

    /**
     * @notice Batch ERC20 token deposit
     * @param _tokenAddress address of the token being sent
     * @param _amounts uint256 array of the amounts of tokens being sent
     * @param _pubKeys20 array of the last 20 bytes of the public keys of the deposit signers
     * @return uint256[] array of indices of the deposits
     */
    function batchMakeDepositERC20(
        address _tokenAddress,
        uint256[] calldata _amounts,
        address[] calldata _pubKeys20
    ) external nonReentrant returns (uint256[] memory) {
        require(
            _amounts.length == _pubKeys20.length,
            "PARAMETERS LENGTH MISMATCH"
        );

        uint256[] memory depositIndexes = new uint256[](_amounts.length);

        for (uint256 i = 0; i < _amounts.length; i++) {
            depositIndexes[i] = makeDeposit(
                _tokenAddress,
                1,
                _amounts[i],
                0,
                _pubKeys20[i]
            );
        }

        return depositIndexes;
    }

    /**
     * @notice Erc721 token receiver function
     * @dev These functions are called by the token contracts when a token is sent to this contract
     * @dev If calldata is "Internal transfer" then the token was sent by this contract and we don't need to do anything
     * @dev Otherwise, calldata needs a 20 byte pubkey20
     * @param _operator address operator requesting the transfer
     * @param _from address address which previously owned the token
     * @param _tokenId uint256 ID of the token being transferred
     * @param _data bytes data to send along with a safe transfer check
     */
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    ) external override returns (bytes4) {
        if (keccak256(_data) == keccak256("Internal transfer")) {
            // if data is "Internal transfer", nothing to do, return
            return this.onERC721Received.selector;
        } else if (_data.length != 20) {
            // if data is not 20 bytes, revert (don't want to accept and lock up tokens!)
            revert("INVALID CALLDATA");
        }

        _operator;

        // create deposit
        deposits.push(
            deposit({
                tokenAddress: msg.sender,
                contractType: 2,
                amount: 1,
                tokenId: _tokenId,
                pubKey20: abi.decode(_data, (address)),
                senderAddress: _from,
                timestamp: block.timestamp
            })
        );

        // emit the deposit event
        emit DepositEvent(deposits.length - 1, 2, 1, _from);

        // return correct bytes4
        return this.onERC721Received.selector;
    }

    /**
        @notice Erc1155 token receiver function
        @dev These functions are called by the token contracts when a token is sent to this contract
        @dev If calldata is "Internal transfer" then the token was sent by this contract and we don't need to do anything
        @dev Otherwise, calldata needs 20 bytes pubKey20
        @param _operator address operator requesting the transfer
        @param _from address address which previously owned the token
        @param _tokenId uint256 ID of the token being transferred
        @param _value uint256 amount of tokens being transferred
        @param _data bytes data passed with the call
     */
    function onERC1155Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        uint256 _value,
        bytes calldata _data
    ) external override returns (bytes4) {
        if (keccak256(_data) == keccak256("Internal transfer")) {
            // if data is "Internal transfer", nothing to do, return
            return this.onERC1155Received.selector;
        } else if (_data.length != 20) {
            // if data is not 20 bytes, revert (don't want to accept and lock up tokens!)
            revert("INVALID CALLDATA");
        }

        // do something with operator so we don't get a warning
        _operator;

        // create deposit
        deposits.push(
            deposit({
                tokenAddress: msg.sender,
                contractType: 3,
                amount: _value,
                tokenId: _tokenId,
                pubKey20: abi.decode(_data, (address)),
                senderAddress: _from,
                timestamp: block.timestamp
            })
        );

        // emit the deposit event
        emit DepositEvent(deposits.length - 1, 3, _value, _from);

        // return correct bytes4
        return this.onERC1155Received.selector;
    }

    /**
     * @notice Erc1155 token receiver function
     * @dev These functions are called by the token contracts when a set of tokens is sent to this contract
     * @dev If calldata is "Internal transfer" then the token was sent by this contract and we don't need to do anything
     * @param _operator address operator requesting the transfer
     * @param _from address address which previously owned the token
     * @param _ids uint256[] IDs of each token being transferred (order and length must match _values array)
     * @param _values uint256[] amount of each token being transferred (order and length must match _ids array)
     * @param _data bytes data forwarded from the caller
     * @dev _data needs to contain array of 20 byte pubKey20s (length must match _ids and _values arrays)
     */
    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external override returns (bytes4) {
        if (keccak256(_data) == keccak256("Internal transfer")) {
            // if data is "Internal transfer", nothing to do, return
            return this.onERC1155BatchReceived.selector;
        } else if (_data.length != (_ids.length * 20)) {
            // dont accept if data is not 20 bytes per token
            revert("INVALID CALLDATA");
        }

        _operator;

        for (uint256 i = 0; i < _ids.length; i++) {
            bytes memory _pubKey20Bytes = new bytes(20);
            for (uint256 j = 0; j < 20; j++) {
                _pubKey20Bytes[j] = _data[i * 20 + j]; // offset + j
            }

            // create deposit
            deposits.push(
                deposit({
                    tokenAddress: msg.sender, // token address (not the address of transaction sender)
                    contractType: 4, // 4 is for ERC1155 (should be uint8)
                    amount: _values[i], // amount of this token
                    tokenId: _ids[i], // token id
                    pubKey20: abi.decode(_pubKey20Bytes, (address)), // convert bytes to address
                    senderAddress: _from,
                    timestamp: block.timestamp
                })
            );

            // emit the deposit event
            emit DepositEvent(
                deposits.length - 1,
                4,
                _values[i], // amount of this token
                _from
            );
        }

        // return correct bytes4
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @notice Function to withdraw a deposit. Withdraws the deposit to the recipient address.
     * @dev _recipientAddressHash is hash("\x19Ethereum Signed Message:\n32" + hash(_recipientAddress))
     * @dev The signature should be signed with the private key corresponding to the public key stored in the deposit
     * @dev We don't check the unhashed address for security reasons. It's preferable to sign a hash of the address.
     * @param _index uint256 index of the deposit
     * @param _recipientAddress address of the recipient
     * @param _recipientAddressHash bytes32 hash of the recipient address (prefixed with "\x19Ethereum Signed Message:\n32")
     * @param _signature bytes signature of the recipient address (65 bytes)
     * @return bool true if successful
     */
    function withdrawDeposit(
        uint256 _index,
        address _recipientAddress,
        bytes32 _recipientAddressHash,
        bytes memory _signature
    ) external nonReentrant returns (bool) {
        // check that the deposit exists and that it isn't already withdrawn
        require(_index < deposits.length, "DEPOSIT INDEX DOES NOT EXIST");
        require(deposits[_index].amount > 0, "DEPOSIT ALREADY WITHDRAWN");
        // check that the recipientAddress hashes to the same value as recipientAddressHash
        require(
            _recipientAddressHash ==
                ECDSA.toEthSignedMessageHash(
                    keccak256(abi.encodePacked(_recipientAddress))
                ),
            "HASHES DO NOT MATCH"
        );
        // check that the signer is the same as the one stored in the deposit
        address depositSigner = getSigner(_recipientAddressHash, _signature);
        require(depositSigner == deposits[_index].pubKey20, "WRONG SIGNATURE");

        uint256 amount = deposits[_index].amount;
        uint8 contractType = deposits[_index].contractType;
        address tokenAddress = deposits[_index].tokenAddress;
        uint256 tokenId = deposits[_index].tokenId;

        // emit the withdraw event
        emit WithdrawEvent(_index, contractType, amount, _recipientAddress);

        // delete the deposit
        delete deposits[_index];

        // Deposit request is valid. Withdraw the deposit to the recipient address.
        if (contractType == 0) {
            /// handle eth deposits
            payable(_recipientAddress).transfer(amount);
        } else if (contractType == 1) {
            /// handle erc20 deposits
            IERC20 token = IERC20(tokenAddress);
            token.transfer(_recipientAddress, amount);
        } else if (contractType == 2) {
            /// handle erc721 deposits
            IERC721 token = IERC721(tokenAddress);
            token.transferFrom(address(this), _recipientAddress, tokenId);
        } else if (contractType == 3) {
            /// handle erc1155 deposits
            IERC1155 token = IERC1155(tokenAddress);
            token.safeTransferFrom(
                address(this),
                _recipientAddress,
                tokenId,
                amount,
                ""
            );
        }

        return true;
    }

    /**
     * @notice Function to allow a sender to withdraw their deposit after 24 hours
     * @param _index uint256 index of the deposit
     * @return bool true if successful
     */
    function withdrawDepositSender(
        uint256 _index
    ) external nonReentrant returns (bool) {
        // Checks-Effects-Interactions

        // check that the deposit exists
        require(_index < deposits.length, "DEPOSIT INDEX DOES NOT EXIST");
        // check that the sender is the one who made the deposit
        require(deposits[_index].senderAddress == msg.sender, "NOT THE SENDER");
        // check that 24 hours have passed since the deposit
        require(
            block.timestamp >= deposits[_index].timestamp + 24 hours,
            "NOT 24 HOURS YET"
        );

        // emit the withdraw event
        emit WithdrawEvent(
            _index,
            deposits[_index].contractType,
            deposits[_index].amount,
            deposits[_index].senderAddress
        );

        uint256 amount = deposits[_index].amount;
        address senderAddress = deposits[_index].senderAddress;
        uint8 contractType = deposits[_index].contractType;
        address tokenAddress = deposits[_index].tokenAddress;
        uint256 tokenId = deposits[_index].tokenId;

        // Delete the deposit
        delete deposits[_index];

        if (contractType == 0) {
            /// handle eth deposits
            payable(senderAddress).transfer(amount);
        } else if (contractType == 1) {
            /// handle erc20 deposits
            IERC20 token = IERC20(tokenAddress);
            token.transfer(senderAddress, amount);
        } else if (contractType == 2) {
            /// handle erc721 deposits
            IERC721 token = IERC721(tokenAddress);
            token.transferFrom(address(this), senderAddress, tokenId);
        } else if (contractType == 3) {
            /// handle erc1155 deposits
            IERC1155 token = IERC1155(tokenAddress);
            token.safeTransferFrom(
                address(this),
                senderAddress,
                tokenId,
                amount,
                ""
            );
        }

        return true;
    }

    //// Some utility functions ////

    /**
     * @notice Gets the signer of a messageHash. Used for signature verification.
     * @dev Uses ECDSA.recover. On Frontend, use secp256k1 to sign the messageHash
     * @dev also remember to prepend the messageHash with "\x19Ethereum Signed Message:\n32"
     * @param messageHash bytes32 hash of the message
     * @param signature bytes signature of the message
     * @return address of the signer
     */
    function getSigner(
        bytes32 messageHash,
        bytes memory signature
    ) internal pure returns (address) {
        address signer = ECDSA.recover(messageHash, signature);
        return signer;
    }

    /**
     * @notice Simple way to get the total number of deposits
     * @return uint256 number of deposits
     */
    function getDepositCount() external view returns (uint256) {
        return deposits.length;
    }

    /**
     * @notice Simple way to get single deposit
        * @param _index uint256 index of the deposit
        * @return Deposit struct
        // TODO: Can also potentially add link time expiry here. Future approach.
    }
        */
    function getDeposit(uint256 _index) external view returns (deposit memory) {
        return deposits[_index];
    }

    // and that's all! Have a nutty day!
}
