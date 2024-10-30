// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {StargateAdapter} from "../src/StargateAdapter.sol";
import {CREATE3Factory} from "@layerzerolabs/create3-factory/contracts/CREATE3Factory.sol";
import "@layerzerolabs/create3-factory/contracts/CREATE3.sol";

import "forge-std/Script.sol";
import "forge-std/console.sol";

abstract contract DeployStargateAdapter is Script {
    function _deployStargateAdapter(
        address _create3Factory,
        address _admin,
        address _addressProvider,
        uint32 _srcEid,
        address _lzEndpoint,
        string memory _forSalt,
        address[] memory _stargatePools,
        uint32[] memory _dstEids
    ) internal returns (address) {
        

        address adapter = _deploy(
            _create3Factory,
            _admin,
            _addressProvider,
            _srcEid,
            _lzEndpoint,
            _forSalt
        );

        
        // address adapter = 0x6eefe99D55AF52CEDe53E757D271b42690865b86;
        

        _setUp(
            adapter,
            _stargatePools,
            _dstEids
        );

        return adapter;
    }

    function _deploy(        
        address _create3Factory,
        address _admin,
        address _addressProvider,
        uint32 _srcEid,
        address _lzEndpoint,
        string memory _forSalt) internal returns (address) 
    {
        uint256 deployerPrivateKey = vm.envUint("MAAT_DEPLOYER_KEY");
        // uint256 deployerPrivateKey = vm.createWallet("MOCK_WALLET").privateKey;
        console.log(vm.addr(deployerPrivateKey));
        vm.startBroadcast(deployerPrivateKey);



        CREATE3Factory factory = CREATE3Factory(_create3Factory);

        bytes32 salt = keccak256(abi.encodePacked(_forSalt));
        bytes memory deployedCode = type(StargateAdapter).creationCode;
        bytes memory params = abi.encode(
            _admin,
            _addressProvider,
            _srcEid,
            _lzEndpoint
        );
        bytes memory creationCode = abi.encodePacked(deployedCode, params);

        address adapter = factory.deploy(salt, creationCode);
        vm.stopBroadcast();
        
        return adapter;
    }


    function _setUp(
        address _adapter,
        address[] memory _stargatePools,
        uint32[] memory _dstEids
    ) internal{
        uint256 adminPrivateKey = vm.envUint("MAAT_ADMIN_KEY");
        // uint256 adminPrivateKey = vm.createWallet("MOCK_WALLET").privateKey;
        console.log(vm.addr(adminPrivateKey));
        vm.startBroadcast(adminPrivateKey);


        StargateAdapter stargateAdapter = StargateAdapter(payable(_adapter));

        for (uint i = 0; i < _stargatePools.length; i++) {
            address stargatePool = _stargatePools[i];

            stargateAdapter.setStargate(stargatePool);
        }

        for (uint i = 0; i < _dstEids.length; i++) {
            stargateAdapter.setDstAdapter(
                _dstEids[i],
                address(stargateAdapter)
            );
        }
    }
}
