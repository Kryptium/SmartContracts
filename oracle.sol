pragma solidity ^0.4.18;

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

    enum Category { football, basket }

    enum EventChange { newEvent, updatedEvent, cancelledEvent, eventOutcomeManuallyFrozen }

    uint private eventNextId;
    uint private subcategoryNextId;

    struct Event { 
        uint id;
        string  title;
        uint  startDateTime;   
        uint  endDateTime;
        uint  subcategoryId;   
        Category  category;   
        uint closeDateTime;     
        uint freezeDateTime;
        bool isCancelled;
    } 

    struct EventOutcome {
        int eventOutcomeNumber1;
        int eventOutcomeNumber2;
        int eventOutcomeNumber3;
        int eventOutcomeNumber4;
        int eventOutcomeNumber5;
        int eventOutcomeNumber6;
        bool isEventOutcomeSet;
    }


    struct OracleData { 
        string  name;
        string  creatorName;
        uint  closeBeforeStartTime;   
        uint  closeEventOutcomeTime;
        uint  createdTimestamp;   
        uint  lastUpdatedTimestamp;        
    } 

    struct Subcategory {
        uint id;
        Category category;
        string name;
        bool hidden;
    }

    OracleData public oracleData;  

    // This creates an array with all sucategories
    mapping (uint => Subcategory) public subcategories;

    // This creates an array with all events
    mapping (uint => Event) public events;

    // This creates an array with all events outcome
    mapping (uint => EventOutcome) public eventsOutcome;


    // Notifies clients that a new oracle is launched
    event OracleCreated(string newName, string newCreatorName, uint closeBeforeStartTime, uint closeEventOutcomeTime, uint timestamp);

    // Notifies clients that an Oracle data has changed
    event OraclePropertiesUpdated(string newName, string newCreatorName, uint closeBeforeStartTime, uint closeEventOutcomeTime, uint timestamp);    

    // Notifies clients that an Oracle subcategory has changed
    event OracleSubcategoriesUpdated(uint id, Category category, string name, bool hidden);    

    // Notifies clients that an Oracle Event has changed
    event UpcomingEventChanged(uint id, string title, uint startDateTime, uint endDateTime, uint subcategory, Category category, uint closeDateTime, uint freezeDateTime, EventChange eventChange);   

    // Notifies clients that an Oracle Event outcome has changed
    event EventOutcomeChanged(uint id, int number1, int number2, int number3, int number4, int number5, int number6);    

    /**
     * Constructor function
     *
     * Initializes Oracle contract
     * Remix sample constructor call "oracleName","oracleCreatorName",1,10
     */
    function Oracle(string oracleName, string oracleCreatorName, uint closeBeforeStartTime, uint closeEventOutcomeTime) public {
        oracleData.name = oracleName;
        oracleData.creatorName = oracleCreatorName;
        oracleData.closeBeforeStartTime = closeBeforeStartTime;
        oracleData.closeEventOutcomeTime = closeEventOutcomeTime;
        oracleData.createdTimestamp = block.timestamp;
        oracleData.lastUpdatedTimestamp = block.timestamp;
        OracleCreated(oracleName, oracleCreatorName, closeBeforeStartTime, closeEventOutcomeTime, oracleData.createdTimestamp);
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
            OraclePropertiesUpdated(oracleData.name, oracleData.creatorName, oracleData.closeBeforeStartTime, oracleData.closeEventOutcomeTime, oracleData.lastUpdatedTimestamp);
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
            OraclePropertiesUpdated(oracleData.name, oracleData.creatorName, oracleData.closeBeforeStartTime, oracleData.closeEventOutcomeTime, oracleData.lastUpdatedTimestamp);
    }      

    /**
     * Adds an Oracle Subcategories
     */
    function setSubcategory(Category category, string name) onlyOwner public {
            subcategoryNextId += 1;
            uint id = subcategoryNextId;
            subcategories[id].id = id;
            subcategories[id].category = category;
            subcategories[id].name = name;
            subcategories[id].hidden = false;
            oracleData.lastUpdatedTimestamp = block.timestamp;
            OracleSubcategoriesUpdated(id, category, name, false);
    }  

    /**
     * Hides an Oracle Subcategory
     */
    function hideSubcategory(uint id) onlyOwner public {
        subcategories[id].hidden = true;
         OracleSubcategoriesUpdated(id, subcategories[id].category, subcategories[id].name, subcategories[id].hidden);  
    }   

    /**
     * Adds an Upcoming Event
     */
    function addUpcomingEvent(string title, uint startDateTime, uint endDateTime, uint subcategoryId, Category category) onlyOwner public {
        require(startDateTime - oracleData.closeEventOutcomeTime<=block.timestamp);
        uint closeDateTime = startDateTime - oracleData.closeEventOutcomeTime;
        uint freezeDateTime = endDateTime + oracleData.closeEventOutcomeTime;
        eventNextId += 1;
        uint id = eventNextId;
        events[id].id = id;
        events[id].title = title;
        events[id].startDateTime = startDateTime;
        events[id].endDateTime = endDateTime;
        events[id].subcategoryId = subcategoryId;
        events[id].category = category;
        events[id].closeDateTime = closeDateTime;
        events[id].freezeDateTime = freezeDateTime;
        UpcomingEventChanged(id, title, startDateTime,endDateTime,subcategoryId,category, closeDateTime, freezeDateTime, EventChange.newEvent);  
    }  

    /**
     * Updates an Upcoming Event
     */
    function updateUpcomingEvent(uint id, string title, uint startDateTime, uint endDateTime, uint subcategoryId, Category category) onlyOwner public {
        uint closeDateTime = startDateTime - oracleData.closeEventOutcomeTime;
        uint freezeDateTime = block.timestamp + oracleData.closeEventOutcomeTime;
        events[id].title = title;
        events[id].startDateTime = startDateTime;
        events[id].endDateTime = endDateTime;
        events[id].subcategoryId = subcategoryId;
        events[id].category = category;
        events[id].closeDateTime = closeDateTime;
        events[id].freezeDateTime = freezeDateTime;
        if (closeDateTime>block.timestamp) {
            events[id].isCancelled = true;
            UpcomingEventChanged(id, title, startDateTime, endDateTime, subcategoryId, category, closeDateTime, freezeDateTime, EventChange.cancelledEvent); 
        } else {
            UpcomingEventChanged(id, title, startDateTime, endDateTime, subcategoryId, category, closeDateTime, freezeDateTime, EventChange.newEvent); 
        }  
    }     

    /**
     * Cancels an Upcoming Event
     */
    function cancelUpcomingEvent(uint id) onlyOwner public {
        require(events[id].freezeDateTime >= block.timestamp);
        events[id].isCancelled = true;
        UpcomingEventChanged(id, events[id].title, events[id].startDateTime, events[id].endDateTime, events[id].subcategoryId, events[id].category, events[id].closeDateTime, events[id].freezeDateTime, EventChange.cancelledEvent); 
    }  


    /**
     * Set outcome of an Event
     */
    function setEventOutcome(uint id, int number1, int number2, int number3, int number4, int number5, int number6) onlyOwner public {
        require(events[id].freezeDateTime >= block.timestamp && events[id].endDateTime >= block.timestamp && !events[id].isCancelled);
        eventsOutcome[id].eventOutcomeNumber1 = number1;
        eventsOutcome[id].eventOutcomeNumber2 = number2;
        eventsOutcome[id].eventOutcomeNumber3 = number3;
        eventsOutcome[id].eventOutcomeNumber4 = number4;
        eventsOutcome[id].eventOutcomeNumber5 = number5;
        eventsOutcome[id].eventOutcomeNumber6 = number6;
        eventsOutcome[id].isEventOutcomeSet = true;
        EventOutcomeChanged(id, eventsOutcome[id].eventOutcomeNumber2, eventsOutcome[id].eventOutcomeNumber2, eventsOutcome[id].eventOutcomeNumber3, eventsOutcome[id].eventOutcomeNumber4, eventsOutcome[id].eventOutcomeNumber5, eventsOutcome[id].eventOutcomeNumber6); 
    }  


    /**
     * set a new freeze datetime of an Event
     */
    function freezeEventOutcome(uint id, uint newFreezeDateTime) onlyOwner public {
        require(eventsOutcome[id].isEventOutcomeSet && !events[id].isCancelled);
        if (newFreezeDateTime > block.timestamp) {
            events[id].freezeDateTime = newFreezeDateTime;
        } else {
            events[id].freezeDateTime = block.timestamp;
        }
        UpcomingEventChanged(id, events[id].title, events[id].startDateTime, events[id].endDateTime, events[id].subcategoryId, events[id].category, events[id].closeDateTime, events[id].freezeDateTime, EventChange.eventOutcomeManuallyFrozen);
    } 

    /**
     * Get event outcome
     */
    function getEventOutcome(uint id) public view returns(int number1, int number2, int number3, int number4, int number5, int number6) {
        require(eventsOutcome[id].isEventOutcomeSet && !events[id].isCancelled);
        return (eventsOutcome[id].eventOutcomeNumber1, eventsOutcome[id].eventOutcomeNumber2, eventsOutcome[id].eventOutcomeNumber3, eventsOutcome[id].eventOutcomeNumber4, eventsOutcome[id].eventOutcomeNumber5, eventsOutcome[id].eventOutcomeNumber6);
    }

    /**
     * Get event Info
     */
    function getEventInfo(uint id) public view returns(string  title, uint  startDateTime, uint  endDateTime, uint  subcategoryId, Category  category, bool isCancelled) {
        return (events[id].title, events[id].startDateTime, events[id].endDateTime, events[id].subcategoryId, events[id].category, events[id].isCancelled);
    }

    /**
     * Get event Info for Houses
     */
    function getEventInfoForHouses(uint id) public view returns(uint  startDateTime, uint  endDateTime, uint closeDateTime, uint freezeDateTime, bool isCancelled, bool eventOutcomeIsSet) {
        return (events[id].startDateTime, events[id].endDateTime, events[id].closeDateTime, events[id].freezeDateTime, events[id].isCancelled, eventsOutcome[id].isEventOutcomeSet);
    }


}