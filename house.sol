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

/*
House smart contract interface
*/
interface OracleContract {
     function getEventForHousePlaceBet(uint id) external view returns (uint closeDateTime, bool isCancelled); 
}

/*
House smart contract interface
*/
interface HouseContract {
     function owner() external view returns (address); 
     function isHouse() external view returns (bool); 
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
        uint  housePercentage;
        uint oraclePercentage;   
        uint version;      
    } 

    address public _newHouseAddress;

    HouseData public houseData;  

    // This creates an array with all events
    mapping (uint => Bet) public bets;

    // User balances
    mapping (address => uint256) public balance;

    // Stores the house owners percentage as part per thousand 
    mapping (address => uint) public ownerPerc;

    //The array of house owners
    address[] public owners;

    //House balance
    uint256 public houseCoins;


    



    // Notifies clients that a new house is launched
    event HouseCreated();

    // Notifies clients that a house data has changed
    event HousePropertiesUpdated();    

    event BetPlaced(uint id);


    /**
     * Constructor function
     *
     * Initializes House contract
     * Remix sample constructor call 1,"JZ HOUSE 2","JZ","GR","0x29dfb91b431a1f12c0e9ae8e11951160ae1a3ebb",["0x29dfb91b431a1f12c0e9ae8e11951160ae1a3ebb"],[50],20,20,100
     */
    constructor(bool managed, string houseName, string houseCreatorName, string houseCountryISO, address oracleAddress, address[] ownerAddress, uint[] ownerPercentage, uint housePercentage,uint oraclePercentage, uint version) public {
        require(add(housePercentage,oraclePercentage)<1000);
        houseData.managed = managed;
        houseData.name = houseName;
        houseData.creatorName = houseCreatorName;
        houseData.countryISO = houseCountryISO;
        houseData.housePercentage = housePercentage;
        houseData.oraclePercentage = oraclePercentage;
        houseData.oracleAddress = oracleAddress;
        houseData.newBetsPaused = true;
        houseData.version = version;
        uint ownersTotal = 0;
        for (uint i = 0; i<ownerAddress.length; i++) {
            owners.push(ownerAddress[i]);
            ownerPerc[ownerAddress[i]] = ownerPercentage[i];
            ownersTotal += ownerPercentage[i];
            }
        require(ownersTotal == 1000);    
        emit HouseCreated();
    }

    /**
     * Check if valid house contract
     */
    function isHouse() public pure returns(bool response) {
        return true;    
    }

     /**
     * Updates House Data function
     *
     */
    function updateHouseProperties(string houseName, string houseCreatorName, string houseCountryISO) onlyOwner public {
        houseData.name = houseName;
        houseData.creatorName = houseCreatorName;
        houseData.countryISO = houseCountryISO;     
        emit HousePropertiesUpdated();
    }    

    /**
     * Updates House Oracle function
     *
     */
    function changeHouseOracle(address oracleAddress, uint oraclePercentage) onlyOwner public {
        require(add(houseData.housePercentage,oraclePercentage)<1000);
        if (oracleAddress != houseData.oracleAddress) {
            houseData.oldOracleAddress = houseData.oracleAddress;
            houseData.oracleAddress = oracleAddress;
        }
        houseData.oraclePercentage = oraclePercentage;
        emit HousePropertiesUpdated();
    } 

    /**
     * Updates House percentage function
     *
     */
    function changeHouseEdge(uint housePercentage) onlyOwner public {
        require(housePercentage != houseData.housePercentage);
        houseData.housePercentage = housePercentage;
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
        bets[id].placedBy = msg.sender;
        emit BetPlaced(id);  
    }  


    function() public payable {
        houseCoins = add(houseCoins,msg.value);
        balance[msg.sender] = add(balance[msg.sender],msg.value);
    }

    function linkToNewHouse(address newHouseAddress) onlyOwner public {
        require(newHouseAddress!=address(this));
        require(HouseContract(newHouseAddress).isHouse());
        _newHouseAddress = newHouseAddress;
        houseData.newBetsPaused = true;
        emit HousePropertiesUpdated();
    }

    function unLinkNewHouse() onlyOwner public {
        _newHouseAddress = address(0);
        houseData.newBetsPaused = false;
        emit HousePropertiesUpdated();
    }


    function withdraw(uint256 amount) public {
        require(houseCoins>=amount);
        require(balance[msg.sender]>=amount);
        balance[msg.sender] = sub(balance[msg.sender],amount);
        houseCoins = sub(houseCoins,amount);
        msg.sender.transfer(amount);
    }

    function withdrawToAddress(address destinationAddress,uint256 amount) public {
        require(houseCoins>=amount);
        require(balance[msg.sender]>=amount);
        balance[msg.sender] = sub(balance[msg.sender],amount);
        houseCoins = sub(houseCoins,amount);
        destinationAddress.transfer(amount);
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