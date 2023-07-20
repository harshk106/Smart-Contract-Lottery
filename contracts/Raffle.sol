// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

//raffle
//ether the lottery(paying some amount)
//pick a random winner (verifiably random)
//winner to be selected every X minutes --> completely automated
//chainlink oracle -> randomness, automated execution(chanlink keepers)

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
import "hardhat/console.sol";

/* Errors */
error Raffle__TransferFailed();
error Raffle__RaffleNotOpen();
error Raffle__SendMoreToEnterRaffle();
error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPLayers, uint256 raffleState);

/** @title a sample Raffle contract
 * @author Harsh Kumbhat 
 * @notice This is contract is for creating an untamperable decentralized smart contract
 * @dev This implements Chainlink VRF v2
 */

contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    /* Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }//uint256 0=OPEN , 1=CALCULATING


    /* State variables */
    // Chainlink VRF Variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // Lottery Variables
    uint256 private immutable i_interval;
    uint256 private immutable i_entranceFee;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    address payable[] private s_players;
    RaffleState private s_raffleState;
    bool private s_isOpen; // to pending , open,closed,calculating

    /*Events*/
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    /* Functions */
    constructor(address vrfCoordinatorV2, uint256 entranceFee,bytes32 gasLane, uint64 subscriptionId, uint256 interval,uint32 callbackGasLimit) VRFConsumerBaseV2(vrfCoordinatorV2){
       i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_entranceFee = entranceFee;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
    }



    function enterRaffle() public payable {
        // require(msg.value >= i_entranceFee, "Not enough value sent");
        // require(s_raffleState == RaffleState.OPEN, "Raffle is not open");
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        // Emit an event when we update a dynamic array or mapping
        // Named events with the function name reversed
        emit RaffleEnter(msg.sender);
    }

    /**
     * @dev this is the function that the chainlink keeper nodes call
     * they look for the 'upkeepNeeded' to return true.
     * following should be true in order to return true
     * 1.Our time interval should have passed
     * 2.the lottery should have at least 1 player,and have some eth
     * 3.our subscription is funded with LINk
     * 4.the lottery should be in an "open" state
     */
    function checkUpkeep(bytes memory /*checkData*/)  public view override returns(bool upkeepNeeded, bytes memory /*performData*/){
            bool isOpen = (RaffleState.OPEN == s_raffleState); 
            // (block.timestamp - last block timestamp) > interval
            bool timePassed = (block.timestamp - s_lastTimeStamp) > i_interval;
            bool hasPLayer = (s_players.length > 0);
            bool hasBalance = address(this).balance >0;
            upkeepNeeded = (isOpen && timePassed && hasPLayer && hasBalance);
    }

    //external functions are cheaper than public ones
    function performUpkeep(bytes calldata /*performdata*/) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        // require(upkeepNeeded, "Upkeep not needed");
        if(!upkeepNeeded){
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState ));
        }
        //request the random no.
        //once we get, do something with it
        //2 transaction process
        //if did one then anyone can brute force and get the no.
        s_raffleState = RaffleState.CALCULATING; //nobody can enter a lottery and updtae 
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, //gas lane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }    

    function fulfillRandomWords(uint256 /*requestId*/ , uint256[] memory randomWords) internal override{
        //random word 256 - 1 winnner 
        //mod function to get winner 
        //if s_player size 10 - randomnmber 202 - 202 % 10
        //will get a no. between 0-9

        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;    //picked a winner
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);

        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        //require(success)
        if(!success){
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(recentWinner);
    }

    /*View / Pure functions */
    function getEntranceFee() public view returns(uint256){
                return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState()public view returns (RaffleState){
        return s_raffleState;
    }

    function getNumWords() public pure returns(uint256){
        return NUM_WORDS;

    }

    function getNumberOfPlayers() public view returns(uint256){
        return s_lastTimeStamp;
    }

    function getrequestConfirmations() public pure returns(uint256){
        return REQUEST_CONFIRMATIONS;
    }

    function getInterval()public view returns(uint256){
        return i_interval;
    }

}
    