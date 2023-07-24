const { AXON_CLIENTS, generate_ibc_handler } = require("./common");

async function send_packet(from_clientId, to_clientId) {
    console.log("send packet from", from_clientId, "to", to_clientId);

    const source = AXON_CLIENTS[from_clientId];
    const target = AXON_CLIENTS[to_clientId];
    const module = await artifacts.require("MockModule").at(source.mock_module);

    // build and send packet
    const denom = "AT";
    const amount = 100;
    const timeoutHeight = 0;
    const result = await module.sendTransfer(denom, amount, target.mock_module, source.port, source.channel, timeoutHeight);
    console.log("send packet result:", result);
}

async function listen_send_packet_event(clientId, callback) {
    const source = AXON_CLIENTS[clientId];
    const handler = generate_ibc_handler(source.handler, artifacts);
    handler.on("SendPacket", (packet) => {
        console.log("receive packet event:", packet);
        callback();
    }).on("error", error => {
        callback(error);
    })
}

module.exports = async (callback) => {
    const source = "07-axon-0";
    const target = "07-axon-1";

    await listen_send_packet_event(source, callback).catch(e => callback(e.toString()));
    await send_packet(source, target).catch(e => callback(e.toString()));
}
