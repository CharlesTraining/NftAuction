// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./AuctionFactory.sol";

contract AuctionFactoryV2 is AuctionFactory {
    uint256 public version;
    event VersionUpgraded(uint256 indexed oldVersion, uint256 indexed newVersion);

    // ============ 初始化 V2 ============
    /**
     * @dev 升级到 V2 版本
     * @param _version 版本号
     */
    function initializeV2(uint256 _version) public reinitializer(2) {
        version = _version;
        emit VersionUpgraded(1, _version);
    }

    // ============ 存储间隙 ============
    uint256[44] private __gap;
}
