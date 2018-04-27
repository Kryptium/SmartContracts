pragma solidity ^0.4.23;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
contract SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b != 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }

    function mulByFraction(uint256 number, uint256 numerator, uint256 denominator) internal pure returns (uint256) {
        return div(mul(number, numerator), denominator);
    }
}

contract Owned {

    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        require(newOwner != 0x0);
        owner = newOwner;
    }
}


interface OracleContract {
     function getEventForHousePlaceBet(uint id) external view returns (uint closeDateTime, bool isCancelled); 
     }


/*
 * ZKBet House Contract.  Copyright © 2018 by ZKBet.
 * Author: Giannis Zarifis <jzarifis@gmail.com>
 */
contract House is SafeMath, Owned {

    //enum Category { football, basket }

    enum BetType { headtohead, multiuser, poolbet }

    uint private betNextId;

    struct Bet { 
        uint id;
        address oracleAddress;
        uint eventId;
        bytes32 forecast; 
        uint256 wager;
        uint closingDateTime;
        uint256 minimumWager;
        uint256 maximumWager;
        uint256 payoutRate;
        address placedBy;
        BetType betType;
        string placedByNickName;
        // uint  createdDateTime;   
        // uint  updatedDateTime;
        bool isCancelled;
    } 


    struct HouseData { 
        bool managed;
        string  name;
        string  creatorName;
        string  countryISO; 
        address oracleAddress;
        address oldOracleAddress;
        bool  newBetsPaused;
        uint  percentage;    
        address[] ownerAddress;
        uint256[] ownerPercentage;   
        // uint  createdTimestamp;   
        // uint  lastUpdatedTimestamp;        
    } 



    HouseData public houseData;  

    // This creates an array with all events
    mapping (uint => Bet) public bets;

    mapping (address => uint256) public balance;


    



    // Notifies clients that a new house is launched
    event HouseCreated();

    // Notifies clients that a house data has changed
    event HousePropertiesUpdated();    

    event BetPlaced(uint id);


    /**
     * Constructor function
     *
     * Initializes House contract
     * Remix sample constructor call 1,"houseName","houseCreatorName","GR","0x692a70d2e424a56d2c6c27aa97d1a86395877b3a",["0x692a70d2e424a56d2c6c27aa97d1a86395877b3a","0xca35b7d915458ef540ade6068dfe2f44e8fa733c"],[50,50],2
     */
    constructor(bool managed, string houseName, string houseCreatorName, string houseCountryISO, address oracleAddress, address[] ownerAddress, uint256[] ownerPercentage, uint housePercentage) public {
        houseData.managed = managed;
        houseData.name = houseName;
        houseData.creatorName = houseCreatorName;
        houseData.countryISO = houseCountryISO;
        houseData.percentage = housePercentage;
        houseData.oracleAddress = oracleAddress;
        houseData.newBetsPaused = true;
        // houseData.createdTimestamp = now;
        // houseData.lastUpdatedTimestamp = now;
        for (uint i = 0; i<ownerAddress.length; i++) {
            houseData.ownerAddress.push(ownerAddress[i]);
            houseData.ownerPercentage.push(ownerPercentage[i]);
            }
        emit HouseCreated();
    }

     /**
     * Updates House Data function
     *
     */
    function updateHouseProperties(string houseName, string houseCreatorName, string houseCountryISO) onlyOwner public {
        houseData.name = houseName;
        houseData.creatorName = houseCreatorName;
        houseData.countryISO = houseCountryISO;     
        //houseData.lastUpdatedTimestamp = now;
        emit HousePropertiesUpdated();
    }    

    /**
     * Updates House Oracle function
     *
     */
    function changeHouseOracle(address oracleAddress) onlyOwner public {
        require(oracleAddress != houseData.oracleAddress);
        houseData.oldOracleAddress = houseData.oracleAddress;
        houseData.oracleAddress = oracleAddress;
       // houseData.lastUpdatedTimestamp = now;
        emit HousePropertiesUpdated();
    } 

    /**
     * Updates House percentage function
     *
     */
    function changeHouseEdge(uint housePercentage) onlyOwner public {
        require(housePercentage != houseData.percentage);
        houseData.percentage = housePercentage;
        //houseData.lastUpdatedTimestamp = now;
        emit HousePropertiesUpdated();
    } 

    //  /**
    //  * Get House info
    //  *
    //  */
    // function getHouseInfo() public view returns(string houseName, string houseCreatorName, string houseCountryISO, address oracleAddress, uint housePercentage) {
    //     return ()
    // }    



    /**
     * Place a Bet
     * Remix sample call 1, 0, "LALA", 10, 0,0,0,0,"Giannis Zarifis"
     */
    function placeBet(uint eventId, BetType betType, bytes32 forecast, uint256 wager, uint closingDateTime, uint256 minimumWager, uint256 maximumWager, uint256 payoutRate, string placedBy) public {
        require(balance[msg.sender]>=wager);
        require(!houseData.newBetsPaused);
        OracleContract oracle = OracleContract(houseData.oracleAddress);
        uint closeDateTime;
        bool isCancelled;
        (closeDateTime, isCancelled) = oracle.getEventForHousePlaceBet(eventId);       
        require(!isCancelled);
        betNextId += 1;
        uint id = betNextId;
        bets[id].id = id;
        bets[id].oracleAddress = houseData.oracleAddress;
        bets[id].eventId = eventId;
        bets[id].betType = betType;
        bets[id].forecast = forecast;
        bets[id].wager = wager;
        if (closingDateTime>0) {
            bets[id].closingDateTime = closingDateTime;
        } else {
            bets[id].closingDateTime = closeDateTime;
        }  
        require(bets[id].closingDateTime >= now);    
        if (minimumWager != 0) {
            bets[id].minimumWager = minimumWager;
        }
        if (maximumWager != 0) {
            bets[id].maximumWager = maximumWager;
        }
        if (payoutRate != 0) {
            bets[id].payoutRate = payoutRate;
        }       
        bets[id].placedByNickName = placedBy;
        bets[id].placedBy = msg.sender;
        emit BetPlaced(id);  
    }  

    // function updateBetOptionalParameters(uint id, uint256 wager, uint closingDateTime, uint256 minimumWager, uint256 maximumWager, uint256 payoutRate, string placedBy) public {
    //     require(msg.sender==bets[id].placedBy);
    //     if (closingDateTime>0) {
    //         bets[id].closingDateTime = closingDateTime;
    //     }        
    //     if (minimumWager != 0) {
    //         bets[id].minimumWager = minimumWager;
    //     }
    //     if (maximumWager != 0) {
    //         bets[id].maximumWager = maximumWager;
    //     }
    //     if (payoutRate != 0) {
    //         bets[id].payoutRate = payoutRate;
    //     }
        
    //     bets[id].placedByNickName = placedBy;
    //     bets[id].updatedDateTime = now;             
    // }


}