// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {StargateAdapter} from "../src/StargateAdapter.sol";

contract Set is Script{

    address stargate = 0xB715B85682B731dB9D5063187C450095c91C57FC;
    
    uint32[] dstEids = [
        30110, //Arbitrum +
        30111, //Optimism +
        30151, //Metis +
        30183, //Linea
        30181, //Mantle + 
        30184, //Base +
        30102, //BSC
        30109, //Polygon + 
        30106 //Avalanche
    ];
    

    function run() public{
        StargateAdapter stargateAdapter = StargateAdapter(payable(0x6eefe99D55AF52CEDe53E757D271b42690865b86));


        uint256 adminPrivateKey = vm.envUint("MAAT_ADMIN_KEY");
        // uint256 adminPrivateKey = vm.createWallet("MOCK_WALLET").privateKey;
        console.log(vm.addr(adminPrivateKey));
        vm.startBroadcast(adminPrivateKey);

        // for (uint i = 0; i<dstEids.length; i++){
        //     stargateAdapter.setDstAdapter(dstEids[i], 0x6eefe99D55AF52CEDe53E757D271b42690865b86);
        // }

        stargateAdapter.setStargate(stargate);


    }

}