import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

function randomDate(start, end) {
    return new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime()));
}

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress, config.dataAddress);
        this.initialize(callback);       
        this.owner = null;
        this.airlines = [];
        this.flights = [];
        this.passengers = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts(async (error, accts) => {
            console.log(error);
            let account = accts[0];
            console.log(account);
           
            this.owner = account;

            let counter = 1;
            
            this.airlines = await this.flightSuretyApp.methods.getRegisteredAirlines().call({ from: self.owner});

            if (!this.airlines || !this.airlines.length) {
                alert("There is no airline available");

            }

            
            while(this.passengers.length < 3) {
                this.passengers.push({
                    account: accts[counter++],
                    passengerSA: 0,
                });
            }

           
            while(this.flights.length < 5) {
                this.flights.push({
                    airline: accts[counter++],
                    flight: "Flight" + Math.floor((Math.random() * 10) + 1),
                    timestamp: randomDate(new Date(), new Date(Date.now() + 1000 * 60 * 60 * 2)),
                });
            }

            callback();
        });
    }

    async buyInsurance(passenger, insurance, flight, callback){
        let self = this;
        let amount = self.web3.utils.toWei(insurance);
        this.addFunds(passenger, insurance);
        await self.flightSuretyApp.methods.buyInsurance(insurance, flight).send({ from: passenger, value: amount,  gas:3000000 }, (error, result) => {
                callback(error, result);
            });
    }

    async getInsuranceAmt(passenger, callback){
        let self = this;
        self.funds = await self.flightSuretyApp.methods.getInsuranceAmt().call({from: passenger});
    }

    getAmt(passenger) {
        let result = 0;
        for (var i=0; i < this.passengers.length; i++) {
            if (this.passengers[i].account === passenger) {
                result = this.passengers[i].passengerSA;
            }
        }
        return result;
    }
    
   
    async withdraw(passenger, callback){
        let self = this;
        let passengerCurrentFund = this.getAmt(passenger);
        alert(this.getAmt(passenger));
       
        await self.flightSuretyApp.methods.withdraw().send({from: passenger, value: passengerCurrentFund}, (error, result) => {
                
                    callback(result);
                
            });
    }

    

    async registerAirline(airline,name, callback){
        let self = this;
        await self.flightSuretyApp.methods.registerAirline(airline,name).send({ from: self.owner}, (error, result) => {
                callback(error, result);
            });
    }

    async payAirlineRegistrationFee(airline,fee, callback){
        let self = this;
        let amount = self.web3.utils.toWei(fee, "ether").toString();
        await self.flightSuretyApp.methods.payAirlineRegistrationFee(airline).send({ from: self.owner, value:amount}, (error, result) => {
                callback(error, result);
            });
    }

    addFunds(passenger, insurance){
        for (var i=0; i < this.passengers.length; i++) {
            if (this.passengers[i].account === passenger) {
                this.passengers[i].passengerSA = insurance;
            }
        }
    }

    getInsuranceAmt(passenger) {
        let result = 0;
        for (var i=0; i < this.passengers.length; i++) {
            if (this.passengers[i].account === passenger) {
                result = this.passengers[i].passengerSA;
            }
        }
        return result;
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        } 
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, payload);
            });
    }
}