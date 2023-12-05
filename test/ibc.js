// import "../../proto/Channel.sol";

const IBCPacket = artifacts.require("IBCPacket");
const IBCHandler = artifacts.require("IBCMockHandler");
const MockModule = artifacts.require("MockModule");

const AXON_MOCK_CLIENT_TYPE = "07-axon";

contract("IBC", (accounts) => {
  it("update client", async () => {
    const ibcHandler = await IBCHandler.deployed();
    // Client Create
    const msgCreateClient = {
      clientType: AXON_MOCK_CLIENT_TYPE,
      consensusState: 1234,
      clientState: 1234,
    };
    const clientId = await ibcHandler.createClient.call(msgCreateClient);
    await ibcHandler.createClient(msgCreateClient);
    console.log("pass create client");
    // Client Update
    const msgUpdateClient = {
      clientId: clientId,
      clientMessage: 1234,
    };
    await ibcHandler.updateClient(msgUpdateClient);
    console.log("pass update client");
  });

  it("actively establish IBC handshake", async () => {
    console.log("start actively establish IBC handshake");
    const ibcHandler = await IBCHandler.deployed();
    // Client Create
    const msgCreateClient = {
      clientType: AXON_MOCK_CLIENT_TYPE,
      consensusState: 1234,
      clientState: 1234,
    };
    const clientId = await ibcHandler.createClient.call(msgCreateClient);
    await ibcHandler.createClient(msgCreateClient);

    // ---------- Connection ---------- //
    // Connection Open Init
    const counterpartyClientId = "counterparty-" + clientId;
    const msgConnectionOpenInit = {
      clientId: clientId,
      counterparty: {
        clientId: counterpartyClientId,
        connectionId: "",
        prefix: {
          keyPrefix: 1234,
        },
      },
      delayPeriod: 0,
    };
    let connectionAttr = await ibcHandler.connectionOpenInit.call(
      msgConnectionOpenInit
    );
    assert.equal(connectionAttr.clientId, clientId, "inconsistent client id");
    assert.equal(
      connectionAttr.counterpartyClientId,
      counterpartyClientId,
      "inconsistent counterparty client id"
    );
    await ibcHandler.connectionOpenInit(msgConnectionOpenInit);
    const connectionId = connectionAttr.connectionId;
    console.log("pass connection open init");
    // Connection Open Ack
    const counterpartyConnectionId = "counterparty-" + connectionId;
    const msgConnectionOpenAck = {
      connectionId: connectionId,
      clientState: 1234,
      version: {
        identifier: "1",
        features: new Array("1"),
      },
      counterpartyConnectionId: counterpartyConnectionId,
      proofTry: 1234,
      proofClient: 1234,
      proofConsensus: 1234,
      proofHeight: { revisionNumber: 0, revisionHeight: 999 },
      consensusHeight: { revisionNumber: 0, revisionHeight: 999 },
    };
    connectionAttr = await ibcHandler.connectionOpenAck.call(
      msgConnectionOpenAck
    );
    await ibcHandler.connectionOpenAck(msgConnectionOpenAck);
    assert.equal(
      connectionAttr.counterpartyConnectionId,
      counterpartyConnectionId,
      "inconsistent counterparty connection id"
    );
    console.log("pass connection open ack");

    // ---------- Channel ---------- //
    // Bind Port
    const portId1 = "port-1";
    const mockModule = await MockModule.deployed();
    await ibcHandler.bindPort(portId1, mockModule.address);
    // Channel Open Init
    const counterpartyPortId = "counterparty-port-1";
    const msgChannelOpenInit = {
      portId: portId1,
      channel: {
        state: 1,
        ordering: 1,
        counterparty: {
          portId: counterpartyPortId,
          channelId: "",
        },
        connectionHops: new Array(connectionId),
        version: "1",
      },
    };
    let channelAttr = await ibcHandler.channelOpenInit.call(msgChannelOpenInit);
    await ibcHandler.channelOpenInit(msgChannelOpenInit);
    let channelId = channelAttr.channelId;
    console.log("pass channel open init");
    // Channel Open Ack
    const counterpartyChannelId = "counterparty-channel-0";
    const msgChannelOpenAck = {
      portId: portId1,
      channelId: channelId,
      counterpartyVersion: "1",
      counterpartyChannelId: counterpartyChannelId,
      proofTry: 1234,
      proofHeight: { revisionNumber: 0, revisionHeight: 999 },
    };
    await ibcHandler.channelOpenAck(msgChannelOpenAck);
    console.log("pass channel open ack");

    // ---------- Packet ---------- //
    // Send Packet
    const msgSendPacket = {
      sequence: 1,
      sourcePort: portId1,
      sourceChannel: channelId,
      destinationPort: counterpartyPortId,
      destinationChannel: counterpartyChannelId,
      data: 1234,
      timeoutHeight: { revisionNumber: 0, revisionHeight: 0 },
      timeoutTimestamp: 0,
    };
    await ibcHandler.sendPacket(msgSendPacket);

    // Recv Packet
    const msgRecvPacket = {
      packet: {
        sequence: 1,
        sourcePort: counterpartyPortId,
        sourceChannel: counterpartyChannelId,
        destinationPort: portId1,
        destinationChannel: channelId,
        data: 1234,
        timeoutHeight: { revisionNumber: 0, revisionHeight: 0 },
        timeoutTimestamp: 0,
      },
      proof: 1234,
      proofHeight: { revisionNumber: 0, revisionHeight: 0 }
    };
    await ibcHandler.recvPacket(msgRecvPacket);
    console.log("pass recv packet");
  });

  it("passively establish IBC handshake", async () => {
    const ibcHandler = await IBCHandler.deployed();
    // Client Create
    const msgCreateClient = {
      clientType: AXON_MOCK_CLIENT_TYPE,
      consensusState: 1234,
      clientState: 1234,
    };
    const clientId = await ibcHandler.createClient.call(msgCreateClient);
    await ibcHandler.createClient(msgCreateClient);

    // ---------- Connection ---------- //
    // Connection Open Try
    const msgConnectionOpenTry = {
      previousConnectionId: "",
      counterparty: {
        clientId: "counterparty-client-0",
        connectionId: "",
        prefix: {
          keyPrefix: 1234,
        },
      },
      delayPeriod: 0,
      clientId: clientId,
      clientState: 1234,
      counterpartyVersions: new Array({
        identifier: "1",
        features: new Array("1"),
      }),
      proofInit: 1234,
      proofClient: 1234,
      proofConsensus: 1234,
      proofHeight: { revisionNumber: 0, revisionHeight: 999 },
      consensusHeight: { revisionNumber: 0, revisionHeight: 999 },
    };
    connectionAttr = await ibcHandler.connectionOpenTry.call(
      msgConnectionOpenTry
    );
    await ibcHandler.connectionOpenTry(msgConnectionOpenTry);
    console.log("pass connection open try");
    const connectionId = connectionAttr.connectionId;
    // Connection Open Confirm
    const msgConnectionOpenConfirm = {
      connectionId: connectionId,
      proofAck: 1234,
      proofHeight: { revisionNumber: 0, revisionHeight: 999 },
    };
    await ibcHandler.connectionOpenConfirm(msgConnectionOpenConfirm);
    console.log("pass connection open confirm");

    // ---------- Channel ---------- //
    // Bind a new Port
    const portId2 = "port-2";
    const mockModule = await MockModule.deployed();
    await ibcHandler.bindPort(portId2, mockModule.address);
    // Channel Open Try
    const counterpartyChannelId = "counterparty-channel-1";
    const counterpartyPortId = "counterparty-" + portId2;
    const msgChannelOpenTry = {
      portId: portId2,
      previousChannelId: "",
      channel: {
        state: 2,
        ordering: 1,
        counterparty: {
          portId: counterpartyPortId,
          channelId: counterpartyChannelId,
        },
        connectionHops: new Array(connectionId),
        version: "1",
      },
      counterpartyVersion: "1",
      proofInit: 1234,
      proofHeight: { revisionNumber: 0, revisionHeight: 999 },
    };
    channelAttr = await ibcHandler.channelOpenTry.call(msgChannelOpenTry);
    await ibcHandler.channelOpenTry(msgChannelOpenTry);
    channelId = channelAttr.channelId;
    console.log("pass channel open try");
    // Channel Open Confirm
    const msgChannelOpenConfirm = {
      portId: portId2,
      channelId: channelId,
      proofAck: 1234,
      proofHeight: { revisionNumber: 0, revisionHeight: 999 },
    };
    await ibcHandler.channelOpenConfirm(msgChannelOpenConfirm);
    console.log("pass channel open confirm");

    // ---------- Packet ---------- //
    // Send Packet
    const msgSendPacket = {
      sequence: 1,
      sourcePort: portId2,
      sourceChannel: channelId,
      destinationPort: counterpartyPortId,
      destinationChannel: counterpartyChannelId,
      data: 1234,
      timeoutHeight: { revisionNumber: 0, revisionHeight: 0 },
      timeoutTimestamp: 0,
    };
    await ibcHandler.sendPacket(msgSendPacket);
    console.log("pass send packet");
    // Recv Packet
    const msgRecvPacket = {
      packet: {
        sequence: 1,
        sourcePort: counterpartyPortId,
        sourceChannel: counterpartyChannelId,
        destinationPort: portId2,
        destinationChannel: channelId,
        data: 1234,
        timeoutHeight: { revisionNumber: 0, revisionHeight: 0 },
        timeoutTimestamp: 0,
      },
      proof: 1234,
      proofHeight: { revisionNumber: 0, revisionHeight: 0 }
    };
    await ibcHandler.recvPacket(msgRecvPacket);
    console.log("pass recv packet");
  });
});
