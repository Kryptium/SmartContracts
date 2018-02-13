pragma solidity ^0.4.16;

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

/*
 * ZKBet Tracker Contract.  Copyright © 2018 by ZKBet.
 * Author: Giannis Zarifis <jzarifis@gmail.com>
 */
contract Oracle is SafeMath, Owned {

    enum Category { football }

    struct OracleData { 
        string  name;
        string  creatorName;
        uint  closeBeforeStartTime;   
        uint  closeEventOutcomeTime;
        uint  createdTimestamp;   
        uint  lastUpdatedTimestamp;        
    } 

    struct Subcategory {
        Category category;
        string name;
        bool hidden;
    }

    OracleData public oracleData;  

    // This creates an array with all sucategories
    mapping (bytes32 => Subcategory) public subcategories;

    // Notifies clients that a new oracle is launched
    event OracleCreated();

    // Notifies clients that an Oracle data has has changed
    event OracleDataUpdated(string newName, string newCreatorName, uint closeBeforeStartTime, uint closeEventOutcomeTime);    

    // Notifies clients that an Oracle subcategory has has changed
    event OracleSubcategoriesUpdated(bytes32 id,Category category, string name, bool hidden);    


    /**
     * Constructor function
     *
     * Initializes Oracle contract
     */
    function Oracle(string trackerName, string trackerCreatorName, uint closeBeforeStartTime, uint closeEventOutcomeTime) public {
        oracleData.name = trackerName;
        oracleData.creatorName = trackerCreatorName;
        oracleData.closeBeforeStartTime = closeBeforeStartTime;
        oracleData.closeEventOutcomeTime = closeEventOutcomeTime;
        oracleData.createdTimestamp = block.timestamp;
        oracleData.lastUpdatedTimestamp = block.timestamp;
        OracleCreated();
    }

     /**
     * Update Oracle Data function
     *
     * Updates Oracle Data
     */
    function updateOracleNames(string newName, string newCreatorName) onlyOwner public {
            oracleData.name = newName;
            oracleData.creatorName = newCreatorName;
            oracleData.lastUpdatedTimestamp = block.timestamp;
            OracleDataUpdated(oracleData.name, oracleData.creatorName, oracleData.closeBeforeStartTime, oracleData.closeEventOutcomeTime);
    }    

     /**
     * Update Oracle Time Constants function
     *
     * Updates Oracle Time Constants
     */
    function setTimeConstants(uint closeBeforeStartTime, uint closeEventOutcomeTime) onlyOwner public {
            oracleData.closeBeforeStartTime = closeBeforeStartTime;
            oracleData.closeEventOutcomeTime = closeEventOutcomeTime;
            oracleData.lastUpdatedTimestamp = block.timestamp;
            OracleDataUpdated(oracleData.name, oracleData.creatorName, oracleData.closeBeforeStartTime, oracleData.closeEventOutcomeTime);
    }      

    /**
     * Adds an Oracle Subcategories
     */
    function setSubcategory(bytes32 id, Category category, string name) onlyOwner public {
            subcategories[id].category = category;
            subcategories[id].name = name;
            subcategories[id].hidden = false;
            oracleData.lastUpdatedTimestamp = block.timestamp;
            OracleSubcategoriesUpdated(id, category, name, false);
    }  

    /**
     * Hides an Oracle Subcategory
     */
    function hideSubcategory(bytes32 id) onlyOwner public {
        subcategories[id].hidden = true;
         OracleSubcategoriesUpdated(id,subcategories[id].category, subcategories[id].name, subcategories[id].hidden);  
    }   

      


}