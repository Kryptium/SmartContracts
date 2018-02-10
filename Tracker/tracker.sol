pragma solidity ^0.4.16;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
contract SafeMath {
    function mul(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal constant returns (uint256) {
        assert(b != 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal constant returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }

    function mulByFraction(uint256 number, uint256 numerator, uint256 denominator) internal returns (uint256) {
        return div(mul(number, numerator), denominator);
    }
}

contract Owned {

    address public owner;

    function Owned() public {
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


interface checkHouse { function isHouse() public; }

/*
 * ZKBet Tracker Contract.  Copyright © 2018 by ZKBet.
 * Author: Giannis Zarifis <jzarifis@gmail.com>
 */
contract Tracker is SafeMath, Owned {

    TrackerData public trackerData;


    enum Action { added, updated, removed }

    struct House { 
        address houseAddress;                 
        uint  upVotes;             
        uint  downVotes;
    }

    struct TrackerData { 
        string  name;
        string  creatorName;
        uint  createdTimestamp;   
        uint  lastUpdateTimestamp;
        bool  managed;
        uint tIP;
    }    

    // This creates an array with all balances
    mapping (address => House) public house;
    mapping (address => mapping (address => uint256)) public allowance;

    // Notifies clients that a house has insterted/altered
    event TrackerChanged(address indexed  houseAddress, Action action);

    // Nnotifies clients that a house has voted
    event HouseVoted(address indexed houseAddress, bool isUpVote);

    // Nnotifies clients that a tracker function invoked
    event TrackerInvoked(uint timeStamp, address invoker);

    /**
     * Constructor function
     *
     * Initializes Tracker contract
     */
    function Tracker(string trackerName, string trackerCreatorName, bool trackerIsManaged, uint tIP) public {
        trackerData.name = trackerName;
        trackerData.creatorName = trackerCreatorName;
        trackerData.createdTimestamp = block.timestamp;
        trackerData.lastUpdateTimestamp = block.timestamp;
        trackerData.managed = trackerIsManaged;
        trackerData.tIP = tIP;
        TrackerInvoked(block.timestamp, msg.sender);
    }


    function kill() onlyOwner public {
        selfdestruct(owner); 
    }

}