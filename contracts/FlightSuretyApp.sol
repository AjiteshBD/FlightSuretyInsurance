pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)
    FlightSuretyData flightSuretyData;
    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract
    mapping(bytes32 => Flight) private flights;
    uint private constant VOTE=4;
    uint private constant CAP = 1 ether;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
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
         // Modify to call data contract's status
        require(flightSuretyData.isOperational(), "Contract is currently not operational");  
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

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address _address)public
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(_address);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns(bool)
    {
        return flightSuretyData.isOperational();  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */
    function registerAirline(address _address)external requireIsOperational returns(bool success, uint256 votes)
    {
        require(flightSuretyData.isAirlineRegistered(msg.sender),"Airline is not registered");
        require(flightSuretyData.isRegistrationFeePaid(msg.sender),"Registration Fee is not paid");
        require(!flightSuretyData.isAirlineRegistered(_address),"Airline is already registered");

        uint registeredAirlines = flightSuretyData.getRegisteredAirlineCount();

        if(registeredAirlines >= VOTE){
            bool duplicate = false;
            for(uint i = 0; i < flightSuretyData.getMultiSigs(); i++)
            {
                if(flightSuretyData.getMultiSig(i) == msg.sender){
                    duplicate = true;
                    break;
                }
            }
            require(!duplicate, "Duplicate function call by Caller");

            flightSuretyData.setMultiSig(msg.sender);
            if(flightSuretyData.getMultiSigs() >= VOTE.div(2)){
                votes = flightSuretyData.getMultiSigs();
                flightSuretyData.clearMultiSig();
                flightSuretyData.registerAirline(_address);
            }
         }else{
            
            flightSuretyData.registerAirline(_address);
         }
        return(success,votes);
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight(address _address, string _flight,uint _time)public requireIsOperational
    {
        bytes32 key = getFlightKey(_address, _flight, _time);
        require(!flights[key].isRegistered, "This flight is already registered");
        flights[key] = Flight({isRegistered:true,statusCode : STATUS_CODE_UNKNOWN, updatedTimestamp:_time, airline : _address});
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus(address airline,string memory flight,uint256 timestamp,uint8 statusCode)public requireIsOperational
    {
        bytes32 key = getFlightKey(airline, flight, timestamp);
        require(!flights[key].isRegistered, "This flight is already registered");
        if(statusCode == STATUS_CODE_LATE_AIRLINE){
            address[]memory insuredPassengers = flightSuretyData.getInsuredPassengers(flight);
            uint amt = 0;
            address passenger;
            for(uint i = 0;i < insuredPassengers.length;i++){
                passenger = insuredPassengers[i];
                amt = flightSuretyData.getPassengerSAOfFlight(flight,passenger);
                flightSuretyData.setPassengerSAOfFlight(flight,passenger,amt);
            }
        }
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(address airline,string flight,uint256 timestamp)external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    }


    function payAirlineRegistrationFee(address _address) external payable requireIsOperational
    {
        flightSuretyData.fund(_address,msg.value);
    }

    function getRegisteredAirlines() external view returns(address[])
    {
        return flightSuretyData.getRegisteredAirlines();
    }

    function buyInsurance(uint _amt,string _flight) external payable
    {
        require(_amt <= CAP, "Cannot take more than 1 ether");
        flightSuretyData.buy(msg.sender,_amt,_flight);
    }

    function withdraw() external payable
    {
        require(msg.sender==0x53Ab6844553981554565Be456ab3D350E6168Ac904a1,"vsdvsvs");
        uint amt = flightSuretyData.getInsurancePay(msg.sender);
        flightSuretyData.creditBalance(amt);
        flightSuretyData.pay(msg.sender, amt.mul(3).div(2));
    }

    function getInsuranceAmt() external view returns(uint)
    {
        return flightSuretyData.getInsurancePay(msg.sender);
    }



// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   
