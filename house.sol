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
     function getEventForHousePlaceBet(uint id) external view returns (uint closeDateTime, uint freezeDateTime, bool isCancelled); 
     function getEventOutcomeIsSet(uint eventId, uint outputId) external view returns (bool isSet);
     function getEventOutcome(uint eventId, uint outputId) external view returns (uint outcome); 
     function getEventOutcomeNumeric(uint eventId, uint outputId) external view returns(uint256 outcome1, uint256 outcome2,uint256 outcome3,uint256 outcome4, uint256 outcome5, uint256 outcome6);
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

    enum BetEvent { placeBet, callBet, removeBet, refuteBet, settleWinnedBet, settleCancelledBet, increaseWager }

    uint private betNextId;

    struct Bet { 
        uint id;
        address oracleAddress;
        uint eventId;
        uint outputId;
        uint outcome;
        bool isOutcomeSet;
        uint closeDateTime;
        uint freezeDateTime;
        bool isCancelled;
        uint256 minimumWager;
        uint256 maximumWager;
        uint256 payoutRate;
        address createdBy;
        BetType betType;
    } 


    struct HouseData { 
        bool managed;
        string  name;
        string  creatorName;
        string  countryISO; 
        string shortMessage;
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

    //Total bets
    uint public totalBets;

    //Total amount played on bets
    uint public totalAmountOnBets;

    //Total amount on Bet
    mapping (uint => uint256) public betTotalAmount;

    //Totalbets on bet
    mapping (uint => uint) public betTotalBets;

    //Bet Refutes
    mapping (uint => uint) public betRefutes;

    //Total amount placed on a bet forecast
    mapping (uint => mapping (uint => uint256)) public betForcastTotalAmount;    

    //Player bet amount of a Bet
    mapping (address => mapping (uint => uint256)) public playerBetTotalAmount;

    //Player forecast for an output of a Bet
    mapping (address => mapping (uint => uint)) public playerBetForeCast;

    //Player wager for a Bet.Output.Forcast
    mapping (address => mapping (uint => mapping (uint => uint256))) public playerBetForecastWager;

    //Player output(Cause or win or refund)  of a bet
    mapping (address => mapping (uint => uint256)) public playerOutputFromBet;    

    //Player bet Refuted
    mapping (address => mapping (uint => bool)) public PlayerBetRefuted;    

    //Player bet Settled
    mapping (address => mapping (uint => bool)) public PlayerBetSettled; 


    //Total bets placed by player
    mapping (address => uint) public totalPlayerBets;


    //Total amount placed for bets by player
    mapping (address => uint256) public totalPlayerBetsAmount;

    // User balances
    mapping (address => uint256) public balance;

    // Stores the house owners percentage as part per thousand 
    mapping (address => uint) public ownerPerc;

    //The array of house owners
    address[] public owners;

    //House balance
    uint256 public houseCoins;

    //The total remaining House amount collected from fees
    uint256 public houseEdgeAmount;

    //The total remaining Oracle amount collected from fees
    mapping (address => uint256) public oracleEdgeAmount;

    //The total House fees
    uint256 public houseTotalFees;

    //The total Oracle fees
    mapping (address => uint256) public oracleTotalFees;

    // Notifies clients that a new house is launched
    event HouseCreated();

    // Notifies clients that a house data has changed
    event HousePropertiesUpdated();    

    event BetPlacedOrModified(uint id, address sender, BetEvent betEvent, uint256);


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


    function updateBetDataFromOracle(uint betId) private {
        if (!bets[betId].isOutcomeSet) {
            (bets[betId].isOutcomeSet) = OracleContract(bets[betId].oracleAddress).getEventOutcomeIsSet(bets[betId].eventId,bets[betId].outputId); 
            if (bets[betId].isOutcomeSet) {
                (bets[betId].outcome) = OracleContract(bets[betId].oracleAddress).getEventOutcome(bets[betId].eventId,bets[betId].outputId); 
            }
        }     
       
        if (!bets[betId].isCancelled) {
            (bets[betId].closeDateTime, bets[betId].freezeDateTime, bets[betId].isCancelled) = OracleContract(bets[betId].oracleAddress).getEventForHousePlaceBet(bets[betId].eventId);      
        }  
        if (!bets[betId].isOutcomeSet && bets[betId].freezeDateTime <= now) {
            bets[betId].isCancelled = true;
        }
    }


    /*
     * Place a Bet
     */
    function placeBet(uint eventId, BetType betType,uint outputId, uint forecast, uint256 wager, uint closingDateTime, uint256 minimumWager, uint256 maximumWager, uint256 payoutRate) public {
        require(balance[msg.sender]>=wager);
        require(!houseData.newBetsPaused);
        betNextId += 1;
        bets[betNextId].id = betNextId;
        bets[betNextId].oracleAddress = houseData.oracleAddress;
        bets[betNextId].outputId = outputId;
        bets[betNextId].eventId = eventId;
        bets[betNextId].betType = betType;
        bets[betNextId].createdBy = msg.sender;
        updateBetDataFromOracle(betNextId);
        require(!bets[betNextId].isCancelled && !bets[betNextId].isOutcomeSet);
        if (closingDateTime>0) {
            bets[betNextId].closeDateTime = closingDateTime;
        }  
        require(bets[betNextId].closeDateTime >= now);
        if (minimumWager != 0) {
            bets[betNextId].minimumWager = minimumWager;
        } else {
            bets[betNextId].minimumWager = wager;
        }
        if (maximumWager != 0) {
            bets[betNextId].maximumWager = maximumWager;
        }
        if (payoutRate != 0) {
            bets[betNextId].payoutRate = payoutRate;
        }       


        betTotalBets[betNextId] += 1;
        betTotalAmount[betNextId] += wager;
        totalBets += 1;
        totalAmountOnBets += wager;
        if (houseData.housePercentage>0) {
            houseEdgeAmount += mulByFraction(wager, houseData.housePercentage, 1000);
        }
        if (houseData.oraclePercentage>0) {
            oracleEdgeAmount[houseData.oracleAddress] += mulByFraction(wager, houseData.oraclePercentage, 1000);
        }

        balance[msg.sender] -= wager;

 
        betForcastTotalAmount[betNextId][forecast] += wager;

        playerBetTotalAmount[msg.sender][betNextId] += wager;

        playerBetForeCast[msg.sender][betNextId] = forecast;

        playerBetForecastWager[msg.sender][betNextId][forecast] = wager;

        totalPlayerBets[msg.sender] += 1;

        totalPlayerBetsAmount[msg.sender] += wager;

        emit BetPlacedOrModified(betNextId, msg.sender, BetEvent.placeBet, wager);
    }  

    /*
     * Call a Bet
     */
    function callBet(uint betId, uint forecast, uint256 wager) public returns (bool) {
        require(balance[msg.sender]>=wager);
        require(betForcastTotalAmount[betId][forecast]!=forecast);
        require(bets[betId].betType != BetType.headtohead || betTotalBets[betId] == 1);
        require(wager>=bets[betId].minimumWager);
        require(bets[betId].maximumWager==0 || wager<=bets[betId].maximumWager);
        updateBetDataFromOracle(betId);
        if (!bets[betId].isCancelled && bets[betId].closeDateTime >= now && !bets[betId].isOutcomeSet) {
            betTotalBets[betId] += 1;
            betTotalAmount[betId] += wager;
            totalAmountOnBets += wager;
            if (houseData.housePercentage>0) {
                houseEdgeAmount += mulByFraction(wager, houseData.housePercentage, 1000);
            }
            if (houseData.oraclePercentage>0) {
                oracleEdgeAmount[bets[betId].oracleAddress] += mulByFraction(wager, houseData.oraclePercentage, 1000);
            }

            balance[msg.sender] -= wager;

    
            betForcastTotalAmount[betId][forecast] += wager;

            playerBetTotalAmount[msg.sender][betId] += wager;

            playerBetForeCast[msg.sender][betId] = forecast;

            playerBetForecastWager[msg.sender][betId][forecast] = wager;

            totalPlayerBets[msg.sender] += 1;

            totalPlayerBetsAmount[msg.sender] += wager;

            emit BetPlacedOrModified(betId, msg.sender, BetEvent.callBet, wager);
            return true;
        } else {
            return false; 
        }
        
    }  

    /*
     * Increase wager
     */
    function increaseWager(uint betId, uint forecast, uint256 additionalWager) public returns (bool) {
        require(balance[msg.sender]>=additionalWager);
        require(betForcastTotalAmount[betId][forecast]!=forecast);
        require(bets[betId].betType != BetType.headtohead || betTotalBets[betId] == 1);
        uint256 wager = playerBetForecastWager[msg.sender][betId][forecast] + additionalWager;
        updateBetDataFromOracle(betId);
        if (!bets[betId].isCancelled && bets[betId].closeDateTime >= now && !bets[betId].isOutcomeSet && (bets[betId].maximumWager==0 || wager<=bets[betId].maximumWager)) {
            betTotalAmount[betId] += additionalWager;
            totalAmountOnBets += additionalWager;
            if (houseData.housePercentage>0) {
                houseEdgeAmount += mulByFraction(additionalWager, houseData.housePercentage, 1000);
            }
            if (houseData.oraclePercentage>0) {
                oracleEdgeAmount[bets[betId].oracleAddress] += mulByFraction(additionalWager, houseData.oraclePercentage, 1000);
            }

            balance[msg.sender] -= additionalWager;
    
            betForcastTotalAmount[betId][forecast] += additionalWager;

            playerBetTotalAmount[msg.sender][betId] += additionalWager;

            playerBetForecastWager[msg.sender][betId][forecast] = additionalWager;

            totalPlayerBetsAmount[msg.sender] += additionalWager;

            emit BetPlacedOrModified(betId, msg.sender, BetEvent.increaseWager, wager);
            return true;
        } else {
            return false; 
        }
        
    }

    /*
     * Remove a Bet
     */
    function removeBet(uint betId) public returns (bool) {
        require(bets[betId].createdBy == msg.sender);
        require(betTotalBets[betId]==1);
        updateBetDataFromOracle(betId);  
        if (bets[betId].closeDateTime >= now) {
            bets[betId].isCancelled = true;
            uint256 wager = betTotalAmount[betId];
            betTotalBets[betId] -= 1;
            betTotalAmount[betId] -= wager;
            totalBets -= 1;
            totalAmountOnBets -= wager;
            houseEdgeAmount = 0;
            oracleEdgeAmount[bets[betId].oracleAddress]  = 0;
            balance[msg.sender] += wager;
            playerBetTotalAmount[msg.sender][betId] -= wager;
            totalPlayerBets[msg.sender] -= 1;
            totalPlayerBetsAmount[msg.sender] -= wager;
            emit BetPlacedOrModified(betId, msg.sender, BetEvent.removeBet, wager);
            return true;
        } else {
            return false;
        }
        
    } 

    /*
     * Refute a Bet
     */
    function refuteBet(uint betId) public returns (bool) {
        require(playerBetTotalAmount[msg.sender][betId]>0);
        require(!PlayerBetRefuted[msg.sender][betId]);
        updateBetDataFromOracle(betId);  
        if (bets[betId].isOutcomeSet && bets[betId].freezeDateTime > now) {
            PlayerBetRefuted[msg.sender][betId] = true;
            betRefutes[betId] += 1;
            if (betRefutes[betId] >= betTotalBets[betId]) {
                bets[betId].isCancelled;   
            }
            emit BetPlacedOrModified(betId, msg.sender, BetEvent.refuteBet, playerBetTotalAmount[msg.sender][betId]);
            return true;
        } else {
            return false;
        }      
    } 

    /*
     * Settle a Bet
     */
    function settleBet(uint betId) public returns (bool) {
        require(playerBetTotalAmount[msg.sender][betId]>0);
        require(!PlayerBetSettled[msg.sender][betId]);
        updateBetDataFromOracle(betId);
        if ((bets[betId].isCancelled || bets[betId].isOutcomeSet) && bets[betId].freezeDateTime <= now) {
            BetEvent betEvent;
            if (bets[betId].isCancelled) {
                betEvent = BetEvent.settleCancelledBet;
                houseEdgeAmount = 0;
                oracleEdgeAmount[bets[betId].oracleAddress] = 0;
                playerOutputFromBet[msg.sender][betId] = playerBetTotalAmount[msg.sender][betId];            
            } else {
                if (houseEdgeAmount > 0) {
                    for (uint i = 0; i<owners.length; i++) {
                        balance[owners[i]] += mulByFraction(houseEdgeAmount, ownerPerc[owners[i]], 1000);
                    }
                    houseTotalFees += houseEdgeAmount;
                    houseEdgeAmount = 0; 
                }   
                if (oracleEdgeAmount[bets[betId].oracleAddress] > 0) {
                    balance[bets[betId].oracleAddress] += oracleEdgeAmount[bets[betId].oracleAddress];
                    oracleTotalFees[bets[betId].oracleAddress] += oracleEdgeAmount[bets[betId].oracleAddress];
                    oracleEdgeAmount[bets[betId].oracleAddress] = 0;
                }
                playerOutputFromBet[msg.sender][betId] = mulByFraction(betTotalAmount[betId], playerBetForecastWager[msg.sender][betId][bets[betId].outcome], betForcastTotalAmount[betId][bets[betId].outcome]);
                if (playerOutputFromBet[msg.sender][betId] > 0) {
                    betEvent = BetEvent.settleWinnedBet;
                }
            }
            PlayerBetSettled[msg.sender][betId] = true;
            balance[msg.sender] += playerOutputFromBet[msg.sender][betId];
            emit BetPlacedOrModified(betId, msg.sender, betEvent, playerOutputFromBet[msg.sender][betId]);
            return true;
        } else {
            return false;
        }
        
        
    } 

    function() public payable {
        houseCoins = add(houseCoins,msg.value);
        balance[msg.sender] = add(balance[msg.sender],msg.value);
    }


    /**
    * Checks if a player has betting activity on House 
    */
    function isPlayer(address playerAddress) public view returns(bool) {
        return (totalPlayerBets[playerAddress] > 0);
    }

    function updateShortMessage(string shortMessage) onlyOwner public {
        houseData.shortMessage = shortMessage;
        emit HousePropertiesUpdated();
    }

    function startNewBets(string shortMessage) onlyOwner public {
        houseData.shortMessage = shortMessage;
        houseData.newBetsPaused = false;
        emit HousePropertiesUpdated();
    }

    function stopNewBets(string shortMessage) onlyOwner public {
        houseData.shortMessage = shortMessage;
        houseData.newBetsPaused = true;
        emit HousePropertiesUpdated();
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

}