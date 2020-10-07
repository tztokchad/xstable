function Events(web3) {
  this.watch = (abi, address, eventName, fromBlock) => {
    return new web3.eth.Contract(abi, address).events[eventName]({ fromBlock });
  };

  this.subscribeToNewBlocks = () => web3.eth.subscribe("newBlockHeaders");
}

module.exports = Events;
