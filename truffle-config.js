var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "rude isolate window chunk monitor fashion into amount chuckle arrange green secret";
//var mnemonic ="spider toast steel voyage eager bone whip feature symptom account very much";

module.exports = {
  networks: {
    development: {
      host:"127.0.0.1",
      port:"7545",
      // provider: function() {
      //   return new HDWalletProvider(mnemonic, "http://127.0.0.1:7545/", 0, 50);
      // },
      network_id: '*',
      gas: 9999999
    }
  },
  compilers: {
    solc: {
      version: "^0.4.24"
    }
  }
};