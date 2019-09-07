pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;
    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
   
    mapping(address => uint256) private authorizedCallers;              // mapping address and authorized caller
    mapping(address => Airline) airlines;                               // Airlines
    address[] private registeredAirlines;                               // array of registered airlines
    mapping(address => Passenger) passengers;                           //passengers address mapping
    mapping(string => address[]) flightPassengers;                      // mapping flight with array of passenger address

    uint private balance = 0;                                           // contract insurance balance
    uint registrationFee = 10;                                          // airline registration fees default is 10
    address[] public multiSig = new address[](0);                       // multiSig consensus
    mapping(string => uint) private totalFlightInsurance;               // total insurance amount in flight
    mapping (address =>uint) private insurancePay;                      // passengers insurance payouts

    /********************************************************************************************/
    /*                                       STRUCT DEFINITIONS                                 */
    /********************************************************************************************/

    // Airline
    struct Airline{      
        bool isRegistered;
        uint funds;
        string name;
    }

    // Passenger
    struct Passenger{
        uint[] sumAssured;
        bool[] isPaid;
        bool isInsured;
        string[] flights;
    }

 
    /********************************************************************************************/
    /*                                  CONSTRUCTOR DEFINITIONS                                 */
    /********************************************************************************************/

   
    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor(address _airline) public
    {
        contractOwner = msg.sender;
        pilotAirline(_airline,"PILOTAIRLINE");
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational()
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireAuthorizedCaller()
    {
        require(authorizedCallers[msg.sender] == 1 , "Caller is not contract owner");
        _;
    }


    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */
    function isOperational() public view returns(bool)
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */
    function setOperatingStatus(bool mode)external requireContractOwner
    {
        operational = mode;
    }

    function kill() external requireContractOwner
    {
        selfdestruct(contractOwner);
    }

    function setRegistrationFee(uint _amt) external requireContractOwner
    {
        registrationFee = _amt;
    }

    function authorizeCaller(address _address) external requireContractOwner
    {
        authorizedCallers[_address] = 1;
    }

    function deauthorizeCaller(address _address) external requireContractOwner
    {
        delete authorizedCallers[_address];
    }

    function isAirlineRegistered(address _airline) external view returns(bool)
    {
        return airlines[_airline].isRegistered;
    }
                               
    function getRegisteredAirlineCount() external view returns(uint)
    {
        return registeredAirlines.length+1;
    }

    function getInsurancePay(address _address)external requireIsOperational returns(uint){
        return insurancePay[_address];
    }

    function doneInsurancePay(address _address) external requireIsOperational{
        insurancePay[_address] = 0;
    }

    function creditBalance(uint _amt) external requireIsOperational{
        balance = balance.sub(_amt);
    }

    function getPassengerSAOfFlight(string _flight,address _address) external requireIsOperational returns(uint){
        uint index = flightDeDup(_address,_flight)-1;
        if(!passengers[_address].isPaid[index])
        {
            return passengers[_address].sumAssured[index];
        }
        return 0;
    }

    function setPassengerSAOfFlight(string _flight,address _address,uint _amt) external requireIsOperational {
        uint index = flightDeDup(_address,_flight)-1;
        passengers[_address].isPaid[index] = true;
        insurancePay[_address] = insurancePay[_address].add(_amt);
    }

    function getInsuredPassengers(string  _flight) external view requireIsOperational returns(address[]){
        return flightPassengers[_flight];
    }

    function getRegisteredAirlines() requireIsOperational public view returns (address[]){
        return registeredAirlines;
    }

    function getMultiSigs() public view returns(uint){
        return multiSig.length;
    }

    function setMultiSig(address _address) public {
        multiSig.push(_address);
    }

    function getMultiSig(uint _index) public view returns (address){
        return multiSig[_index];
    }

    function clearMultiSig() public{
        multiSig = new address[](0);
    }

    function isRegistrationFeePaid(address _address) public view requireIsOperational returns (bool){
        return airlines[_address].funds >= registrationFee;
    }

    function flightDeDup(address _address, string memory _flight) public view returns(uint index){
        string[] memory flights = new string[](5);
        flights = passengers[_address].flights;
        for(uint i = 0;i<flights.length; i++){
            if(uint(keccak256(abi.encodePacked(flights[i]))) == uint(keccak256(abi.encodePacked(_flight)))){
                return (i+1);
            }
        }

        return 0;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/


    function pilotAirline(address _address,string _name)internal requireIsOperational{
        airlines[_address] = Airline({isRegistered :true,funds :0,name:_name});
        registeredAirlines.push(_address); 
    }

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    
    function registerAirline(address _address,string _name) external requireIsOperational
    {
        airlines[_address] = Airline({isRegistered:true,funds:0,name:_name});
        registeredAirlines.push(_address);       
    }


   /**
    * @dev Buy insurance for a flight
    *
    */
    function buy(address _address,uint _insuranceamt,string _flight) external payable requireIsOperational
    {
        string[] memory flights = new string[](3);
        bool[] memory paid = new bool[](3);
        uint[] memory insuranceamt = new uint[](3);
        uint index;

        if(passengers[_address].isInsured){
            index = flightDeDup(_address,_flight);
            require(index==0,"Passenger already Insured for this flight");

            passengers[_address].isPaid.push(false);
            passengers[_address].sumAssured.push(_insuranceamt);
            passengers[_address].flights.push(_flight);
        }else{
            paid[0] = false;
            insuranceamt[0] =_insuranceamt;
            flights[0] = _flight;
            passengers[_address] = Passenger({sumAssured : insuranceamt,isPaid:paid,isInsured:true,flights:flights});

        }

        insurancePay[_address] = _insuranceamt;
        balance = balance.add(_insuranceamt);
        flightPassengers[_flight].push(_address);
        totalFlightInsurance[_flight] = totalFlightInsurance[_flight].add(_insuranceamt);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    // function creditInsurees
    //                             (
    //                             )
    //                             external
    //                             pure
    // {
    // }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay(address _account,uint amt) public payable requireIsOperational
    {
        _account.transfer(amt);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */
    function fund(address _address, uint _amt)public payable
    {
        airlines[_address].funds = airlines[_address].funds.add(_amt);
        balance = balance.add(_amt);
    }

    function getFlightKey(address airline,string memory flight,uint256 timestamp) pure internal returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable
    {
       balance = balance.add(msg.value);
    }


}

