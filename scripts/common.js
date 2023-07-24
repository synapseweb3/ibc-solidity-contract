const ethers = require("ethers");

const AXON_CLIENTS = {
    "07-axon-0": {
        handler: "0xD61210E756f7D71Cc4F74abF0747D65Ea9d7525b",
        mock_module: "0x7aB5cEee0Ff304b053CE1F67d84C33F0ff407a55",
        channel: "channel-0",
        port: "port-0"
    },
    "07-axon-1": {
        handler: "0xe4a4B3Bc2787aA913e5b4bbce907e8b213250BDe",
        mock_module: "0xD962a5F050A5F0a2f8dF82aFc04CF1afFE585082",
        channel: "channel-0",
        port: "port-0"
    },
}

function generate_ibc_handler(address, artifacts) {
    const abi = new ethers.utils.Interface(artifacts.require("OwnableIBCHandler").abi);
    const provider = new ethers.providers.WebSocketProvider(process.env.AXON_RPC_URL);
    const handler = new ethers.Contract(address, abi, provider);
    return handler;
}

module.exports = {
    AXON_CLIENTS,
    generate_ibc_handler
};
