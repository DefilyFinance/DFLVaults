// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./StratX4.sol";

contract StratX4_SINGLE_BECO is StratX4 {
    constructor(
        address[] memory _addresses,
        address[] memory _addressesX2,
        uint256 _pid,
        bool[] memory _typeSettings,
        address[] memory _earnedToAUTOPath,
        address[] memory _earnedToToken0Path,
        address[] memory _earnedToToken1Path,
        address[] memory _earnedToToken0PathX2,
        address[] memory _earnedToToken1PathX2,
        address[] memory _token0ToEarnedPath,
        address[] memory _token1ToEarnedPath,
        address[] memory _token0ToWantPathX2,
        address[] memory _token1ToWantPathX2,
        uint256 _safeSwapFactor,
        uint256[] memory _fees
    ) public {
        wbnbAddress = _addresses[0];
        govAddress = _addresses[1];
        autoFarmAddress = _addresses[2];
        AUTOAddress = _addresses[3];

        wantAddress = _addresses[4];
        token0Address = _addresses[5];
        token1Address = _addresses[6];
        earnedAddress = _addresses[7];

        farmContractAddress = _addresses[8];
        pid = _pid;
        isCAKEStaking = _typeSettings[0];
        isSingleStaking = _typeSettings[1];
        isAutoComp = _typeSettings[2];

        uniRouterAddress = _addresses[9];
        earnedToAUTOPath = _earnedToAUTOPath;
        earnedToToken0Path = _earnedToToken0Path;
        earnedToToken1Path = _earnedToToken1Path;
        token0ToEarnedPath = _token0ToEarnedPath;
        token1ToEarnedPath = _token1ToEarnedPath;

        earnedToToken0PathX2 = _earnedToToken0PathX2;
        earnedToToken1PathX2 = _earnedToToken1PathX2;
        token0ToWantPathX2 = _token0ToWantPathX2;
        token1ToWantPathX2 = _token1ToWantPathX2;
        vaultX2Address = _addressesX2[0];
        wantAddressX2 = _addressesX2[1];
        token0AddressX2 = _addressesX2[2];
        token1AddressX2 = _addressesX2[3];
        earnedAddressX2 = _addressesX2[4];
        farmContractAddressX2 = _addressesX2[5];

        controllerFee = _fees[0];
        rewardsAddress = _addresses[10];
        buyBackRate = _fees[1];
        buyBackAddress = _addresses[11];
        entranceFeeFactor = _fees[2];
        withdrawFeeFactor = _fees[3];
        safeSwapFactor = _safeSwapFactor;

        transferOwnership(autoFarmAddress);
    }
}
