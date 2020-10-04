function Events(web3) {
  this.watch = (abi, address, eventName, fromBlock) => {
    return new web3.eth.Contract(abi, address).events[eventName]({ fromBlock });
  };
}

module.exports = Events;
