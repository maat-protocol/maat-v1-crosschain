// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {DeployStargateAdapter} from "./DeployStargateAdapter.sol";

contract Deploy is DeployStargateAdapter{

    address create3Factory = 0xB1FD46396F277AB91D0E6c6Ac859a05616436ad1;
    address admin = 0x7BF9B9166509164282188DD7d812E2b1a16b2dd9;
    address maatAddressProviderV1 = 0x6CA228Aadd078fcf54254F90FA15C85BcFF761dD;
    address lzEndpoint = 0x1a44076050125825900e736c501f859c50fE728c;

    string salt = "MAAT.V1.0.StargateAdapter";

    uint32[] eids = [
        30110, //Arbitrum  +
        30111, //Optimism  +
        30151, //Metis +
        30183, //Linea -
        30181, //Mantle +
        30184, //Base +
        30102, //BSC +
        30109, //Polygon  + 
        30106, //Avalanche  +
        30280 //Sei
        ];

    //CHAIN DATA
    // uint32 srcEid = 30280;
    // address[] stargatePools = [
    //     0x45d417612e177672958dC0537C45a8f8d754Ac2E,
    //     0x0dB9afb4C33be43a0a0e396Fd1383B4ea97aB10a
    //     ];
    // uint32[] dstEids = [
    //     30110, //Arbitrum
    //     30111, //Optimism
    //     30151, //Metis
    //     30183, //Linea
    //     30181, //Mantle
    //     30184, //Base
    //     30102, //BSC
    //     30109, //Polygon
    //     30106 //Avalanche
    // ];
    

    function run() public{

        address[] memory seiStargatePools = new address[](2);
        seiStargatePools[0] = 0x45d417612e177672958dC0537C45a8f8d754Ac2E;
        seiStargatePools[1] = 0x0dB9afb4C33be43a0a0e396Fd1383B4ea97aB10a;

        // deployAndSetup(30280, seiStargatePools);
        address stargateAdapter = 0x6eefe99D55AF52CEDe53E757D271b42690865b86;
        setUpAdapter(stargateAdapter, 30280, seiStargatePools);

        // adjustNewChain(0x6eefe99D55AF52CEDe53E757D271b42690865b86 , 30280);
    }

    function deployAndSetup(uint32 _newChainEid, address[] memory _newStargatePools) public{

        uint32[] memory _dstEids = new uint32[](eids.length - 1);

        for (uint i = 0; i < eids.length; i++) {
            if (eids[i] != _newChainEid) {
                _dstEids[i] = eids[i];
            }
        }

        console.log('eids length: ', eids.length);
        console.log("dstEids length: ", _dstEids.length);

        address stargateAdapter = address(_deployStargateAdapter(create3Factory, admin, maatAddressProviderV1, _newChainEid, lzEndpoint, salt, _newStargatePools, _dstEids));

        console.log("StargateAdapter deployed at: ", stargateAdapter);
    }


    function setUpAdapter(address _stargateAdapter, uint32 _newChainEid, address[] memory _newStargatePools) public{
        uint32[] memory _dstEids = new uint32[](eids.length - 1);

        for (uint i = 0; i < eids.length; i++) {
            if (eids[i] != _newChainEid) {
                _dstEids[i] = eids[i];
            }
        }
        console.log('eids length: ', eids.length);
        console.log("dstEids length: ", _dstEids.length);

        _setUp(_stargateAdapter, _newStargatePools, _dstEids);
    }

    function adjustNewChain(address _stargateAdapter, uint32 _newChainEid) public{

        uint32[] memory newDstEids = new uint32[](1);
        address[] memory newStargatePools;

        newDstEids[0] = _newChainEid; // Directly assign the value

        _setUp(_stargateAdapter, newStargatePools, newDstEids);
    }

}