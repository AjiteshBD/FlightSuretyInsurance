
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(airlines) Pilot airline is registered when contract is deployed`,async function (){
    let status = await config.flightSuretyData.isAirlineRegistered(config.firstAirline);
    assert.equal(status,true,"Pilot airline is not registered");    
  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];
    let result =true;

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {
        result = false;
    }
     result = await config.flightSuretyData.isRegistrationFeePaid(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it(`(Passenger) can buy Insurance`,async()=>{
    let fee = config.flightSuretyApp.REGISTRATION_FEE;
    let result = false;

    try{
        await config.flightSuretyApp.buyInsurance(fee,"TestFlight",{from:config.firstAirline});
    }catch(e){
        result = true;
        console.log(`ddd:`+fee);
    }
    assert.equal(result,false,"Error while buying Insurance");
  });

  it(`(airline) Only registered four airline can register a new airline`,async()=>{
    let newAirline1 = accounts[3];
    let newAirline2 = accounts[4];
    let newAirline3 = accounts[5];
    
    let fee =10000000000000000000;

     let output1 = false;
     let output2 = false;
     let output3 = false;
     

    try{
        await config.flightSuretyApp.payAirlineRegistrationFee(config.firstAirline, {from: config.firstAirline,value:fee});
        await config.flightSuretyApp.registerAirline(newAirline1, {from: config.firstAirline});

        await config.flightSuretyApp.payAirlineRegistrationFee(newAirline1, {from: newAirline1,value:fee});
        await config.flightSuretyApp.registerAirline(newAirline2,{from: newAirline1});       

        output1 =  await config.flightSuretyData.isAirlineRegistered(newAirline1);       
        output2 =  await config.flightSuretyData.isAirlineRegistered(newAirline2);
      

        await config.flightSuretyApp.payAirlineRegistrationFee(newAirline2, {from: newAirline2,value:fee});
        await config.flightSuretyApp.registerAirline(newAirline3,{from: newAirline2});

        output3 =  await config.flightSuretyData.isAirlineRegistered(newAirline3);
    }catch(e)
    {
        console.log(output1,output2,output4);
        console.log(e);

    }
    assert(output1==true&& output2==true&& output3==false,`Only existing airline may register a new airline`);

  });
 

  it('(multiparty) registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airliner', async () => {

    let newAirline = accounts[9];
    let newAirline2 = accounts[6];
    let newAirline3 = accounts[7];
    let newAirline4 = accounts[8];

    let funds = 10000000000000000000; 
    let result=true;
    try{
        await config.flightSuretyApp.registerAirline(newAirline2, {from: config.firstAirline});
        await config.flightSuretyApp.payAirlineRegistrationFee(newAirline2, {from: newAirline2, value: funds}); 
        await config.flightSuretyApp.registerAirline(newAirline3, {from: newAirline2});
        await config.flightSuretyApp.registerAirline(newAirline4, {from: config.firstAirline});
        await config.flightSuretyApp.registerAirline(newAirline, {from: newAirline2});
        await config.flightSuretyApp.payAirlineRegistrationFee(newAirline4, {from: newAirline2, value: funds});
    
        result = await config.flightSuretyData.isAirlineRegistered.call(newAirline);
    }catch(e){
        console.log(e);
    }
    

    assert.equal(result, false, "Airline was not registered.");

});

});
