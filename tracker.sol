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


interface houseContract {
     function owner() external constant returns (address); 
     function isHouse() external constant returns (bool); 
     }

/*
 * ZKBet Tracker Contract.  Copyright © 2018 by ZKBet.
 * Author: Giannis Zarifis <jzarifis@gmail.com>
 */
contract Tracker is SafeMath, Owned {




    enum Action { added, updated, removed }

    struct House {            
        uint upVotes;             
        uint downVotes;
        bool isActive;
        address oldAddress;
        address owner;
    }

    struct TrackerData { 
        string  name;
        string  creatorName;
        uint  createdTimestamp;   
        uint  lastUpdatedTimestamp;
        bool  managed;
        uint trackerVersion;
    }    


    TrackerData public trackerData;

    // This creates an array with all balances
    mapping (address => House) public houses;

    // Notifies clients that a house has insterted/altered
    event TrackerChanged(address indexed  newHouseAddress, address indexed oldHouseAddress, Action action);

    // Notifies clients that a house has voted
    event HouseVoted(address indexed houseAddress, bool isUpVote);

    // Notifies clients that a new tracker is launched
    event TrackerCreated();

    // Notifies clients that a Tracker names has has changed
    event TrackerNamesUpdated();    


    /**
     * Constructor function
     *
     * Initializes Tracker data
     */
    constructor(string trackerName, string trackerCreatorName, bool trackerIsManaged) public {
        trackerData.name = trackerName;
        trackerData.creatorName = trackerCreatorName;
        trackerData.createdTimestamp = now;
        trackerData.lastUpdatedTimestamp = now;
        trackerData.managed = trackerIsManaged;
        trackerData.trackerVersion = 1;
        emit TrackerCreated();
    }

     /**
     * Update Tracker Data function
     *
     * Updates trackersstats
     */
    function updateTrackerNames(string newName, string newCreatorName) onlyOwner public {
            trackerData.name = newName;
            trackerData.creatorName = newCreatorName;
            trackerData.lastUpdatedTimestamp = now;
            emit TrackerNamesUpdated();
    }    

     /**
     * Add House function
     *
     * Adds a new house
     */
    function addHouse(address houseAddress) public {
        require(!trackerData.managed || msg.sender==owner);
        require(!houses[houseAddress].isActive);    
        // TODO check if ZKBet House smart contract
        houses[houseAddress] = House(0,0,true,0x0,msg.sender);
        trackerData.lastUpdatedTimestamp = now;
        emit TrackerChanged(houseAddress,0x0,Action.added);
    }

    /**
     * Update House function
     *
     * Updates a house 
     */
    function updateHouse(address newHouseAddress,address oldHouseAddress) public {
        require(!trackerData.managed || msg.sender==owner);
        require(houses[oldHouseAddress].owner==msg.sender || houses[oldHouseAddress].owner==oldHouseAddress);  
        // TODO check if ZKBet House smart contract
        houses[oldHouseAddress].isActive = false;
        houses[newHouseAddress].isActive = true;
        houses[newHouseAddress].upVotes = houses[oldHouseAddress].upVotes;
        houses[newHouseAddress].downVotes = houses[oldHouseAddress].downVotes;
        houses[newHouseAddress].oldAddress = oldHouseAddress;
        trackerData.lastUpdatedTimestamp = now;
        emit TrackerChanged(newHouseAddress,oldHouseAddress,Action.updated);
    }

     /**
     * Remove House function
     *
     * Removes a house
     */
    function removeHouse(address houseAddress) public {
        require(!trackerData.managed || msg.sender==owner);
        require(houses[houseAddress].owner==msg.sender || houses[houseAddress].owner==houseAddress);  
        // TODO check if ZKBet House smart contract
        houses[houseAddress].isActive = false;
        trackerData.lastUpdatedTimestamp = now;
        emit TrackerChanged(houseAddress,houseAddress,Action.removed);
    }

     /**
     * UpVote House function
     *
     * UpVotes a house
     */
    function upVoteHouse(address houseAddress) public {
        houses[houseAddress].upVotes += 1;
        trackerData.lastUpdatedTimestamp = now;
        emit HouseVoted(houseAddress,true);
    }

     /**
     * DownVote House function
     *
     * DownVotes a house
     */
    function downVoteHouse(address houseAddress) public {
        houses[houseAddress].upVotes -= 1;
        trackerData.lastUpdatedTimestamp = now;
        emit HouseVoted(houseAddress,false);
    }    

    /**
     * Kill function
     *
     * Contract Suicide
     */
    function kill() onlyOwner public {
        selfdestruct(owner); 
    }

}