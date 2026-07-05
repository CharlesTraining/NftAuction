// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title AuctionMath
 * @dev 拍卖数学库，提供拍卖相关的纯计算函数
 *
 */
library AuctionMath {
    /**
     * @dev 检查出价是否高于保留价
     * @param bidUSD 出价的美元价值（6位精度）
     * @param reservePriceUSD 保留价（6位精度）
     * @return 是否达标
     *
     *
     */
    function isAboveReserve(uint256 bidUSD, uint256 reservePriceUSD) internal pure returns (bool) {
        unchecked {
            return bidUSD >= reservePriceUSD;
        }
    }

    /**
     * @dev 检查拍卖是否已过期
     * @param endTime 结束时间戳
     * @return 是否已过期
     *
     *
     */
    function isExpired(uint256 endTime) internal view returns (bool) {
        unchecked {
            return block.timestamp >= endTime;
        }
    }

    /**
     * @dev 检查拍卖是否已开始
     * @param startTime 开始时间戳
     * @return 是否已开始
     */
    function isStarted(uint256 startTime) internal view returns (bool) {
        unchecked {
            return block.timestamp >= startTime;
        }
    }

    /**
     * @dev 计算剩余时间
     * @param endTime 结束时间戳
     * @return 剩余秒数（已过期返回0）
     */
    function getRemainingTime(uint256 endTime) internal view returns (uint256) {
        unchecked {
            if (block.timestamp >= endTime) return 0;
            return endTime - block.timestamp;
        }
    }
}
