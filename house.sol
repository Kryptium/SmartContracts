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
Oracle smart contract interface
*/
interface OracleContract {
    function owner() external view returns (address);
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
        address oracleAddress;
        address oldOracleAddress;       
        bool  newBetsPaused;
        uint  housePercentage;
        uint oraclePercentage;   
        uint version;
        string shortMessage;              
    } 

    address public _newHouseAddress;

    HouseData public houseData;  

    // This creates an array with all bets
    mapping (uint => Bet) public bets;

    //Total bets
    uint public totalBets;

    //Total amount played on bets
    uint public totalAmountOnBets;

    //Total amount on Bet
    mapping (uint => uint256) public betTotalAmount;

    //Totalbets on bet
    mapping (uint => uint) public betTotalBets;

    //Bet Refutes amount
    mapping (uint => uint256) public betRefutedAmount;

    //Total amount placed on a bet forecast
    mapping (uint => mapping (uint => uint256)) public betForcastTotalAmount;    

    //Player bet total amount on a Bet
    mapping (address => mapping (uint => uint256)) public playerBetTotalAmount;

    //Player wager for a Bet.Output.Forcast
    mapping (address => mapping (uint => mapping (uint => uint256))) public playerBetForecastWager;

    //Player output(Cause or win or refund)  of a bet
    mapping (address => mapping (uint => uint256)) public playerOutputFromBet;    

    //Player bet Refuted
    mapping (address => mapping (uint => bool)) public playerBetRefuted;    

    //Player bet Settled
    mapping (address => mapping (uint => bool)) public playerBetSettled; 


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

    //The House and Oracle Edge has been paid
    mapping (uint => bool) public housePaid;

    //The total remaining House amount collected from fees for Bet
    mapping (uint => uint256) public houseEdgeAmountForBet;

    //The total remaining Oracle amount collected from fees for Bet
    mapping (uint => uint256) public oracleEdgeAmountForBet;

    //The total House fees
    uint256 public houseTotalFees;

    //The total Oracle fees
    mapping (address => uint256) public oracleTotalFees;

    // Notifies clients that a new house is launched
    event HouseCreated();

    // Notifies clients that a house data has changed
    event HousePropertiesUpdated();    

    event BetPlacedOrModified(uint id, address sender, BetEvent betEvent, uint256 amount, uint forecast);


    /**
     * Constructor function
     *
     * Initializes House contract
     * Remix sample constructor call 1,"JZ HOUSE 2","JZ","GR","0x29dfb91b431a1f12c0e9ae8e11951160ae1a3ebb",["0x29dfb91b431a1f12c0e9ae8e11951160ae1a3ebb"],[50],20,20,100
     */
    constructor(bool managed, string houseName, string houseCreatorName, string houseCountryISO, address oracleAddress, address[] ownerAddress, uint[] ownerPercentage, uint housePercentage,uint oraclePercentage, uint version) public {
        require(add(housePercentage,oraclePercentage)<1000,"House + Oracle percentage should be lower than 100%");
        houseData.managed = managed;
        houseData.name = houseName;
        houseData.creatorName = houseCreatorName;
        houseData.countryISO = houseCountryISO;
        houseData.housePercentage = housePercentage;
        houseData.oraclePercentage = oraclePercentage; 
        houseData.oracleAddress = oracleAddress;
        houseData.shortMessage = "";
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
        require(add(houseData.housePercentage,oraclePercentage)<1000,"House + Oracle percentage should be lower than 100%");
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
        require(housePercentage != houseData.housePercentage,"New percentage is identical with current");
        require(add(housePercentage,houseData.oraclePercentage)<1000,"House + Oracle percentage should be lower than 100%");
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
        require(wager>0,"Wager should be greater than zero");
        require(balance[msg.sender]>=wager,"Not enough balance");
        require(!houseData.newBetsPaused,"Bets are paused right now");
        betNextId += 1;
        bets[betNextId].id = betNextId;
        bets[betNextId].oracleAddress = houseData.oracleAddress;
        bets[betNextId].outputId = outputId;
        bets[betNextId].eventId = eventId;
        bets[betNextId].betType = betType;
        bets[betNextId].createdBy = msg.sender;
        updateBetDataFromOracle(betNextId);
        require(!bets[betNextId].isCancelled,"Event has been cancelled");
        require(!bets[betNextId].isOutcomeSet,"Event has already an outcome");
        if (closingDateTime>0) {
            bets[betNextId].closeDateTime = closingDateTime;
        }  
        require(bets[betNextId].closeDateTime >= now,"Close time has passed");
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
            houseEdgeAmountForBet[betNextId] += mulByFraction(wager, houseData.housePercentage, 1000);
        }
        if (houseData.oraclePercentage>0) {
            oracleEdgeAmountForBet[betNextId] += mulByFraction(wager, houseData.oraclePercentage, 1000);
        }

        balance[msg.sender] -= wager;

 
        betForcastTotalAmount[betNextId][forecast] += wager;

        playerBetTotalAmount[msg.sender][betNextId] += wager;

        playerBetForecastWager[msg.sender][betNextId][forecast] = wager;

        totalPlayerBets[msg.sender] += 1;

        totalPlayerBetsAmount[msg.sender] += wager;

        emit BetPlacedOrModified(betNextId, msg.sender, BetEvent.placeBet, wager, forecast);
    }  

    /*
     * Call a Bet
     */
    function callBet(uint betId, uint forecast, uint256 wager) public returns (bool) {
        require(wager>0,"Wager should be greater than zero");
        require(balance[msg.sender]>=wager,"Not enough balance");
        require(playerBetForecastWager[msg.sender][betId][forecast] == 0,"Already placed a bet for this forecast, use increaseWager method instead");
        require(bets[betId].betType != BetType.headtohead || betTotalBets[betId] == 1,"Head to head bet has been already called");
        require(wager>=bets[betId].minimumWager,"Wager is lower than the minimum accepted");
        require(bets[betId].maximumWager==0 || wager<=bets[betId].maximumWager,"Wager is higher then the maximum accepted");
        updateBetDataFromOracle(betId);
        if (!bets[betId].isCancelled && bets[betId].closeDateTime >= now && !bets[betId].isOutcomeSet) {
            betTotalBets[betId] += 1;
            betTotalAmount[betId] += wager;
            totalAmountOnBets += wager;
            if (houseData.housePercentage>0) {
                houseEdgeAmountForBet[betId] += mulByFraction(wager, houseData.housePercentage, 1000);
            }
            if (houseData.oraclePercentage>0) {
                oracleEdgeAmountForBet[betId] += mulByFraction(wager, houseData.oraclePercentage, 1000);
            }

            balance[msg.sender] -= wager;

    
            betForcastTotalAmount[betId][forecast] += wager;

            playerBetTotalAmount[msg.sender][betId] += wager;

            playerBetForecastWager[msg.sender][betId][forecast] = wager;

            totalPlayerBets[msg.sender] += 1;

            totalPlayerBetsAmount[msg.sender] += wager;

            emit BetPlacedOrModified(betId, msg.sender, BetEvent.callBet, wager, forecast);
            return true;
        } else {
            return false; 
        }
        
    }  

    /*
     * Increase wager
     */
    function increaseWager(uint betId, uint forecast, uint256 additionalWager) public returns (bool) {
        require(additionalWager>0,"Increase wager amount should be greater than zero");
        require(balance[msg.sender]>=additionalWager,"Not enough balance");
        require(playerBetForecastWager[msg.sender][betId][forecast] > 0,"Haven't placed any bet");
        require(bets[betId].betType != BetType.headtohead || betTotalBets[betId] == 1,"Head to head bet has been already called");
        uint256 wager = playerBetForecastWager[msg.sender][betId][forecast] + additionalWager;
        require(bets[betId].maximumWager==0 || wager<=bets[betId].maximumWager,"The updated wager is higher then the maximum accepted");
        updateBetDataFromOracle(betId);
        if (!bets[betId].isCancelled && bets[betId].closeDateTime >= now && !bets[betId].isOutcomeSet) {
            betTotalAmount[betId] += additionalWager;
            totalAmountOnBets += additionalWager;
            if (houseData.housePercentage>0) {
                houseEdgeAmountForBet[betId] += mulByFraction(additionalWager, houseData.housePercentage, 1000);
            }
            if (houseData.oraclePercentage>0) {
                oracleEdgeAmountForBet[betId] += mulByFraction(additionalWager, houseData.oraclePercentage, 1000);
            }

            balance[msg.sender] -= additionalWager;
    
            betForcastTotalAmount[betId][forecast] += additionalWager;

            playerBetTotalAmount[msg.sender][betId] += additionalWager;

            playerBetForecastWager[msg.sender][betId][forecast] += additionalWager;

            totalPlayerBetsAmount[msg.sender] += additionalWager;

            emit BetPlacedOrModified(betId, msg.sender, BetEvent.increaseWager, wager, forecast);
            return true;
        } else {
            return false; 
        }
        
    }

    /*
     * Remove a Bet
     */
    function removeBet(uint betId) public returns (bool) {
        require(bets[betId].createdBy == msg.sender,"Caller and player created don't match");
        require(betTotalBets[betId]==1,"The bet has been called by other player");
        updateBetDataFromOracle(betId);  
        if (bets[betId].closeDateTime >= now) {
            bets[betId].isCancelled = true;
            uint256 wager = betTotalAmount[betId];
            betTotalBets[betId] -= 1;
            betTotalAmount[betId] -= wager;
            totalBets -= 1;
            totalAmountOnBets -= wager;
            houseEdgeAmountForBet[betId] = 0;
            oracleEdgeAmountForBet[betId] = 0;
            balance[msg.sender] += wager;
            playerBetTotalAmount[msg.sender][betId] -= wager;
            totalPlayerBets[msg.sender] -= 1;
            totalPlayerBetsAmount[msg.sender] -= wager;
            emit BetPlacedOrModified(betId, msg.sender, BetEvent.removeBet, wager,0);
            return true;
        } else {
            return false;
        }
        
    } 

    /*
     * Refute a Bet
     */
    function refuteBet(uint betId) public returns (bool) {
        require(playerBetTotalAmount[msg.sender][betId]>0,"Caller hasn't placed any bet");
        require(!playerBetRefuted[msg.sender][betId],"Already refuted");
        updateBetDataFromOracle(betId);  
        if (bets[betId].isOutcomeSet && bets[betId].freezeDateTime > now) {
            playerBetRefuted[msg.sender][betId] = true;
            betRefutedAmount[betId] += playerBetTotalAmount[msg.sender][betId];
            if (betRefutedAmount[betId] >= betTotalAmount[betId]) {
                bets[betId].isCancelled;   
            }
            emit BetPlacedOrModified(betId, msg.sender, BetEvent.refuteBet, playerBetTotalAmount[msg.sender][betId],0);
            return true;
        } else {
            return false;
        }      
    } 

    /*
     * Calculates bet outcome for player
     */
    function calculateBetOutcome(uint betId, bool isCancelled, uint forecast) public view returns (uint256 betOutcome) {
        require(playerBetTotalAmount[msg.sender][betId]>0, "Caller hasn't placed any bet");
        require(!playerBetSettled[msg.sender][betId],"Already settled");
        if (isCancelled) {
            return playerBetTotalAmount[msg.sender][betId];            
        } else {
            if (betForcastTotalAmount[betId][forecast]>0) {
                uint256 totalBetAmountAfterFees = betTotalAmount[betId] - houseEdgeAmountForBet[betId] - oracleEdgeAmountForBet[betId];
                return mulByFraction(totalBetAmountAfterFees, playerBetForecastWager[msg.sender][betId][forecast], betForcastTotalAmount[betId][forecast]);            
            } else {
                return playerBetTotalAmount[msg.sender][betId] - mulByFraction(playerBetTotalAmount[msg.sender][betId], houseData.housePercentage, 1000) - mulByFraction(playerBetTotalAmount[msg.sender][betId], houseData.oraclePercentage, 1000);
            }
        }
    }

    /*
     * Settle a Bet
     */
    function settleBet(uint betId) public returns (bool) {
        require(playerBetTotalAmount[msg.sender][betId]>0, "Caller hasn't placed any bet");
        require(!playerBetSettled[msg.sender][betId],"Already settled");
        updateBetDataFromOracle(betId);
        if ((bets[betId].isCancelled || bets[betId].isOutcomeSet) && bets[betId].freezeDateTime <= now) {
            BetEvent betEvent;
            if (bets[betId].isCancelled) {
                betEvent = BetEvent.settleCancelledBet;
                houseEdgeAmountForBet[betId] = 0;
                oracleEdgeAmountForBet[betId] = 0;
                playerOutputFromBet[msg.sender][betId] = playerBetTotalAmount[msg.sender][betId];            
            } else {
                if (!housePaid[betId] && houseEdgeAmountForBet[betId] > 0) {
                    for (uint i = 0; i<owners.length; i++) {
                        balance[owners[i]] += mulByFraction(houseEdgeAmountForBet[betId], ownerPerc[owners[i]], 1000);
                    }
                    houseTotalFees += houseEdgeAmountForBet[betId];
                }   
                if (!housePaid[betId] && oracleEdgeAmountForBet[betId] > 0) {
                    address oracleOwner = HouseContract(bets[betId].oracleAddress).owner();
                    balance[oracleOwner] += oracleEdgeAmountForBet[betId];
                    oracleTotalFees[bets[betId].oracleAddress] += oracleEdgeAmountForBet[betId];
                }
                if (betForcastTotalAmount[betId][bets[betId].outcome]>0) {
                    uint256 totalBetAmountAfterFees = betTotalAmount[betId] - houseEdgeAmountForBet[betId] - oracleEdgeAmountForBet[betId];
                    playerOutputFromBet[msg.sender][betId] = mulByFraction(totalBetAmountAfterFees, playerBetForecastWager[msg.sender][betId][bets[betId].outcome], betForcastTotalAmount[betId][bets[betId].outcome]);            
                } else {
                    playerOutputFromBet[msg.sender][betId] = playerBetTotalAmount[msg.sender][betId] - mulByFraction(playerBetTotalAmount[msg.sender][betId], houseData.housePercentage, 1000) - mulByFraction(playerBetTotalAmount[msg.sender][betId], houseData.oraclePercentage, 1000);
                }
                if (playerOutputFromBet[msg.sender][betId] > 0) {
                    betEvent = BetEvent.settleWinnedBet;
                }
            }
            housePaid[betId] = true;
            playerBetSettled[msg.sender][betId] = true;
            balance[msg.sender] += playerOutputFromBet[msg.sender][betId];
            emit BetPlacedOrModified(betId, msg.sender, betEvent, playerOutputFromBet[msg.sender][betId],0);
            return true;
        } else {
            return false;
        }      
    } 

    function() public payable {
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
        require(newHouseAddress!=address(this),"New address is current address");
        require(HouseContract(newHouseAddress).isHouse(),"New address should be a House smart contract");
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
        require(address(this).balance>=amount,"Insufficient House balance. Shouldn't have happened");
        require(balance[msg.sender]>=amount,"Insufficient balance");
        balance[msg.sender] = sub(balance[msg.sender],amount);
        msg.sender.transfer(amount);
    }

    function withdrawToAddress(address destinationAddress,uint256 amount) public {
        require(address(this).balance>=amount);
        require(balance[msg.sender]>=amount,"Insufficient balance");
        balance[msg.sender] = sub(balance[msg.sender],amount);
        destinationAddress.transfer(amount);
    }

}