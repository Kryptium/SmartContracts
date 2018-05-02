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
 * ZKBet Oracle Contract.  Copyright © 2018 by ZKBet.
 * Author: Giannis Zarifis <jzarifis@gmail.com>
 */
contract Oracle is SafeMath, Owned {

    enum Category { football, basket }

    enum EventChange { newEvent, updatedEvent, cancelledEvent, eventOutcomeManuallyFrozen }

    enum EventOutputType { multichoice, numeric }

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
        string announcement;
        uint totalAvailableOutputs;
    } 

    struct EventOutcome {
        uint outcome1;
        uint outcome2;
        uint outcome3;
        uint outcome4;
        uint outcome5;
        uint outcome6;
    }


    struct EventOutputParameter {
        EventOutputType eventOutputType;
        string title;
        string[] possibleResults;        
    }

    struct EventOutput {
        bool isSet;
        string title;
        uint possibleResultsCount;
        mapping (uint => string) possibleResults;  
        EventOutputType  eventOutputType;
        bool isEventOutcomeSet;   
    }


    struct OracleData { 
        string  name;
        string  creatorName;
        uint  closeBeforeStartTime;   
        uint  closeEventOutcomeTime;
        uint version;      
    } 

    struct Subcategory {
        uint id;
        Category category;
        string name;
        string country;
        bool hidden;
    }

    OracleData public oracleData;  

    // This creates an array with all sucategories
    mapping (uint => Subcategory) public subcategories;

    // This creates an array with all events
    mapping (uint => Event) public events;

    // Event output Outcome
    mapping (uint => mapping (uint => EventOutput)) public eventOutputs;

    //Event output outcome
    mapping (uint => mapping (uint => uint)) public eventOutcome;

    //Event output outcome numeric
    mapping (uint => mapping (uint => EventOutcome)) public eventNumericOutcomes;



    // Notifies clients that a new oracle is launched
    event OracleCreated();

    // Notifies clients that an Oracle data has changed
    event OraclePropertiesUpdated();    

    // Notifies clients that an Oracle subcategory has changed
    event OracleSubcategoriesUpdated(uint id, Category category, string name,string country, bool hidden);    

    // Notifies clients that an Oracle Event has changed
    event UpcomingEventChanged(uint id, string title, uint startDateTime, uint endDateTime, uint subcategory, Category category, uint closeDateTime, uint freezeDateTime, EventChange eventChange);

    // Notifies clients that an Oracle Event outcome has changed
    event EventOutcomeChanged(uint eventId, uint outputId);

    // Notifies clients that an Oracle Event added
    event UpcomingEventAdded(uint eventId);

    // Notifies clients that an Oracle Event added
    event UpcomingEventUpdated(uint eventId);

    /**
     * Constructor function
     *
     * Initializes Oracle contract
     * Remix sample constructor call "oracleName","oracleCreatorName",15,20
     */
    constructor(string oracleName, string oracleCreatorName, uint closeBeforeStartTime, uint closeEventOutcomeTime, uint version) public {
        oracleData.name = oracleName;
        oracleData.creatorName = oracleCreatorName;
        oracleData.closeBeforeStartTime = closeBeforeStartTime;
        oracleData.closeEventOutcomeTime = closeEventOutcomeTime;
        oracleData.version = version;
        emit OracleCreated();
    }

     /**
     * Update Oracle Data function
     *
     * Updates Oracle Data
     */
    function updateOracleNames(string newName, string newCreatorName) onlyOwner public {
        oracleData.name = newName;
        oracleData.creatorName = newCreatorName;
        emit OraclePropertiesUpdated();
    }    

     /**
     * Update Oracle Time Constants function
     *
     * Updates Oracle Time Constants
     */
    function setTimeConstants(uint closeBeforeStartTime, uint closeEventOutcomeTime) onlyOwner public {
        oracleData.closeBeforeStartTime = closeBeforeStartTime;
        oracleData.closeEventOutcomeTime = closeEventOutcomeTime;
        emit OraclePropertiesUpdated();
    }      

    /**
     * Adds an Oracle Subcategories
     */
    function setSubcategory(Category category, string name,string country) onlyOwner public {
        subcategoryNextId += 1;
        uint id = subcategoryNextId;
        subcategories[id].id = id;
        subcategories[id].category = category;
        subcategories[id].name = name;
        subcategories[id].country = country;
        subcategories[id].hidden = false;
        emit OracleSubcategoriesUpdated(id, category, name, country, false);
    }  

    /**
     * Hides an Oracle Subcategory
     */
    function hideSubcategory(uint id) onlyOwner public {
        subcategories[id].hidden = true;
        emit OracleSubcategoriesUpdated(id, subcategories[id].category, subcategories[id].name,subcategories[id].country, subcategories[id].hidden);
    }   

    /**
     * Adds an Upcoming Event
     * Remix sample call "OSFP-PAO", 1521755089, 1521752289, 0, 0,[{"title":"LALA","eventOutputType":0,"possibleResults":["HOME","DRAW","AWAY"]}]
     * Remix sample call "AEK-PAOK", 1519431000, 1519431600, 1, 0
     */
    function addUpcomingEvent(string title, uint startDateTime, uint endDateTime, uint subcategoryId, Category category, string outputTitle, EventOutputType eventOutputType, bytes32[] _possibleResults) onlyOwner public {        
        uint closeDateTime = startDateTime - oracleData.closeEventOutcomeTime * 1 minutes;
        uint freezeDateTime = endDateTime + oracleData.closeEventOutcomeTime * 1 minutes;
        require(closeDateTime >= now);
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
        events[id].totalAvailableOutputs = 1;
        eventOutputs[id][events[id].totalAvailableOutputs].isSet = true;
        eventOutputs[id][events[id].totalAvailableOutputs].title = outputTitle;
        eventOutputs[id][events[id].totalAvailableOutputs].possibleResultsCount = _possibleResults.length;
        eventOutputs[id][events[id].totalAvailableOutputs].eventOutputType = eventOutputType;
        for (uint j = 0; j<_possibleResults.length; j++) {
            eventOutputs[id][events[id].totalAvailableOutputs].possibleResults[j] = _possibleResults[j];            
        }

        emit UpcomingEventAdded(id);
    }  

    /**
     * Updates an Upcoming Event
     * Remix sample call 1, "AEK-PAOK", 1519456520, 1519456700, 1, 0
     */
    function updateUpcomingEvent(uint id, string title, uint startDateTime, uint endDateTime, uint subcategoryId, Category category) onlyOwner public {
        uint closeDateTime = startDateTime - oracleData.closeEventOutcomeTime * 1 minutes;
        uint freezeDateTime = endDateTime + oracleData.closeEventOutcomeTime * 1 minutes;
        events[id].title = title;
        events[id].startDateTime = startDateTime;
        events[id].endDateTime = endDateTime;
        events[id].subcategoryId = subcategoryId;
        events[id].category = category;
        events[id].closeDateTime = closeDateTime;
        events[id].freezeDateTime = freezeDateTime;
        if (closeDateTime < now) {
            events[id].isCancelled = true;
        }  
        emit UpcomingEventUpdated(id); 
    }     

    /**
     * Cancels an Upcoming Event
     */
    function cancelUpcomingEvent(uint id) onlyOwner public {
        require(events[id].freezeDateTime >= now);
        events[id].isCancelled = true;
        emit UpcomingEventUpdated(id); 
    }  


    /**
     * Set the numeric type outcome of Event output
     */
    function setEventOutcomeNumeric(uint eventId, uint outputId, string announcement, bool setEventAnnouncement, uint outcome1, uint outcome2,uint outcome3,uint outcome4, uint outcome5, uint outcome6) onlyOwner public {
        require(events[eventId].freezeDateTime > now && events[eventId].endDateTime < now && !events[eventId].isCancelled);
        require(eventOutputs[eventId][outputId].isSet && eventOutputs[eventId][outputId].eventOutputType == EventOutputType.numeric);
        eventNumericOutcomes[eventId][outputId].outcome1 = outcome1;
        eventOutputs[eventId][outputId].isEventOutcomeSet = true;
        if (setEventAnnouncement) {
            events[eventId].announcement = announcement;
        }     
        emit EventOutcomeChanged(eventId, outputId); 
    }  

     /**
     * Set the outcome of Event output
     */
    function setEventOutcome(uint eventId, uint outputId, string announcement, bool setEventAnnouncement, uint _eventOutcome ) onlyOwner public {
        require(events[eventId].freezeDateTime > now && events[eventId].endDateTime < now && !events[eventId].isCancelled);
        require(eventOutputs[eventId][outputId].isSet && eventOutputs[eventId][outputId].eventOutputType == EventOutputType.multichoice);
        eventOutputs[eventId][outputId].isEventOutcomeSet = true;
        eventOutcome[eventId][outputId] = _eventOutcome;
        if (setEventAnnouncement) {
            events[eventId].announcement = announcement;
        } 
        emit EventOutcomeChanged(eventId, outputId); 
    } 


    /**
     * set a new freeze datetime of an Event
     */
    function freezeEventOutcome(uint id, uint newFreezeDateTime) onlyOwner public {
        require(!events[id].isCancelled);
        if (newFreezeDateTime > now) {
            events[id].freezeDateTime = newFreezeDateTime;
        } else {
            events[id].freezeDateTime = now;
        }
        emit UpcomingEventUpdated(id);
    } 

    /**
     * Get event outcome numeric
     */
    function getEventOutcomeNumeric(uint eventId, uint outputId) public view returns(uint outcome1, uint outcome2,uint outcome3,uint outcome4, uint outcome5, uint outcome6) {
        require(eventOutputs[eventId][outputId].isSet && !events[eventId].isCancelled && eventOutputs[eventId][outputId].eventOutputType==EventOutputType.numeric);
        return (eventNumericOutcomes[eventId][outputId].outcome1,eventNumericOutcomes[eventId][outputId].outcome2,eventNumericOutcomes[eventId][outputId].outcome3,eventNumericOutcomes[eventId][outputId].outcome4,eventNumericOutcomes[eventId][outputId].outcome5,eventNumericOutcomes[eventId][outputId].outcome6);
    }

        /**
     * Get event outcome
     */
    function getEventOutcome(uint eventId, uint outputId) public view returns(uint outcome) {
        require(eventOutputs[eventId][outputId].isSet && !events[eventId].isCancelled && eventOutputs[eventId][outputId].eventOutputType==EventOutputType.multichoice);
        return (eventOutcome[eventId][outputId]);
    }



    /**
     * Get event Info for Houses
     */
    function getEventForHousePlaceBet(uint id) public view returns(uint closeDateTime, uint freezeDateTime, bool isCancelled) {
        return (events[id].closeDateTime,events[id].freezeDateTime, events[id].isCancelled);
    }


}