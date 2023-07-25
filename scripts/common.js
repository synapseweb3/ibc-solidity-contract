const ethers = require("ethers");

const AXON_CLIENTS = {
    "07-axon-0": {
        handler: "0xf975A646FCa589Be9fc4E0C28ea426A75645fB1f",
        mock_module: "0xAaC7D4A36DAb95955ef3c641c23F1fA46416CF71",
        channel: "channel-0",
        port: "port-0"
    },
    "07-axon-1": {
        handler: "0x7E27bCbe2F0eDdA3E0AA12492950a6B8703b00FB",
        mock_module: "0x9015957A2210BB8B10e27d8BBEEF8d9498f123eF",
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
