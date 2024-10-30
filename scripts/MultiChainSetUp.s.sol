// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {StargateAdapter} from "../src/StargateAdapter.sol";
import {IStargateAdapter} from "../src/interfaces/IStargateAdapter.sol";
import {CREATE3Factory} from "@layerzerolabs/create3-factory/contracts/CREATE3Factory.sol";
import "@layerzerolabs/create3-factory/contracts/CREATE3.sol";

// import {ITokenVault} from "./interfaces/ITokenVault.sol"; //!CUSTOM INTERFACE
import {IMaatAddressProvider} from "@maat-v1-core/src/interfaces/IMaatAddressProvider.sol";

import "forge-std/Script.sol";
import "forge-std/console.sol";

contract MultiChainSetUp is Script {
    string configPath =
        string.concat(vm.projectRoot(), "/scripts/AddressConfig.json");
    string jsonConfig = vm.readFile(configPath);

    CREATE3Factory factory =
        CREATE3Factory(0xB1FD46396F277AB91D0E6c6Ac859a05616436ad1);

    bytes32 salt = keccak256(abi.encodePacked("MAAT.V0.0.3.STARGATEADAPTER"));

    //! ORDER Keys by alphabet!
    struct NetworkConfig {
        address addressProvider;
        address admin;
        uint256 eid;
        address lzEndpoint;
        address stargateAdapter;
        address[] stargatePools;
        address[] tokens;
    }

    function setUpAdapter(string memory network) public {
        NetworkConfig memory config = _getNetworkConfig(network);

        address adapter = deployAdapter(
            config.admin,
            config.addressProvider,
            uint32(config.eid),
            config.lzEndpoint
        );

        _writeToConfig(
            string.concat(".", network, ".stargateAdapter"),
            vm.toString(adapter)
        );

        IMaatAddressProvider addressProvider = IMaatAddressProvider(
            config.addressProvider
        );

        addressProvider.changeStargateAdapter(adapter);

        // Setting Up Adapter
        _setStargatePeers(adapter, network, config);
    }

    function _setStargatePeers(
        address adapter,
        string memory network,
        NetworkConfig memory config
    ) internal {
        IStargateAdapter stargateAdapter = IStargateAdapter(payable(adapter));

        string[] memory networks = vm.parseJsonKeys(jsonConfig, "$");

        // uint256 adminPrivateKey = vm.envUint("MAAT_ADMIN_KEY");
        uint256 adminPrivateKey = vm.createWallet("MOCK_WALLET").privateKey;
        console.log(vm.addr(adminPrivateKey));
        vm.startBroadcast(adminPrivateKey);

        for (uint i = 0; i < config.stargatePools.length; i++) {
            address stargatePool = config.stargatePools[i];

            stargateAdapter.setStargate(stargatePool);
        }

        for (uint i = 0; i < networks.length; i++) {
            string memory dstNetwork = networks[i];

            if (_compareStrings(network, dstNetwork)) continue;

            string memory key = string.concat(".", dstNetwork, ".eId");
            uint32 dstEid = uint32(
                abi.decode(vm.parseJson(jsonConfig, key), (uint256))
            );

            key = string.concat(".", dstNetwork, ".stargateAdapter");
            address dstAdapter = abi.decode(
                vm.parseJson(jsonConfig, key),
                (address)
            );

            if (stargateAdapter.getDstAdapter(dstEid) != dstAdapter)
                stargateAdapter.setDstAdapter(dstEid, dstAdapter);
        }

        vm.stopBroadcast();
    }

    function deployAdapter(
        address admin,
        address addressProvider,
        uint32 srcEid,
        address lzEndpoint
    ) public returns (address) {
        bytes memory deployedCode = type(StargateAdapter).creationCode;
        bytes memory params = abi.encode(
            admin,
            addressProvider,
            srcEid,
            lzEndpoint
        );
        bytes memory creationCode = abi.encodePacked(deployedCode, params);

        //TODO: Check if address already deployed
        // uint256 deployerPrivateKey = vm.envUint("MAAT_DEPLOYER_KEY");
        uint256 deployerPrivateKey = vm.createWallet("MOCK_WALLET").privateKey;
        vm.broadcast(deployerPrivateKey);
        address deployedContract = factory.deploy(salt, creationCode);

        console.log("Deployed contract address: ", deployedContract);
        return deployedContract;
    }

    function _writeToConfig(string memory key, string memory data) internal {
        bytes memory encodedExistingData = vm.parseJson(
            jsonConfig,
            string.concat(".", key)
        );
        string memory existingData = abi.decode(encodedExistingData, (string));

        if (_compareStrings(existingData, data)) return;

        vm.writeJson(data, configPath, key);
        jsonConfig = vm.readFile(configPath);
    }

    function _getNetworkConfig(
        string memory network
    ) internal view returns (NetworkConfig memory config) {
        bytes memory encodedConfig = vm.parseJson(
            jsonConfig,
            string.concat(".", network)
        );

        config = abi.decode(encodedConfig, (NetworkConfig));
    }

    function _compareStrings(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }

    // function toString(address addr) public returns (string memory) {
    //     return vm.toString(addr);
    // }

    function run() public {
        string[2] memory dstNetworks = ["arbitrum", "base"];

        for (uint i = 0; i < dstNetworks.length; i++) {
            string memory network = dstNetworks[i];

            vm.createSelectFork(vm.rpcUrl(network));

            setUpAdapter(network);
        }
    }
}
