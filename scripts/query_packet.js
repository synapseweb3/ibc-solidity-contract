const { AXON_CLIENTS, generate_ibc_handler } = require("./common");

async function query_packet_commitment_sequences(clientId) {
    const client = AXON_CLIENTS[clientId];
    const handler = generate_ibc_handler(client.handler, artifacts);
    const next_sequence = await handler.getNextSequenceSend(client.port, client.channel);
    console.log("max sequence:", next_sequence.toString());
    for (let i = 0; i < parseInt(next_sequence.toString()); i++) {
        const result = await handler.getHashedPacketCommitment(client.port, client.channel, i);
        console.log("result on", i, result);
    }
    const sequences = await handler.getHashedPacketCommitmentSequences(client.port, client.channel);
    console.log("packet sequences:", sequences);
}

module.exports = async (callback) => {
    await query_packet_commitment_sequences("07-axon-0").catch(e => callback(e.toString()));
    callback();
}
