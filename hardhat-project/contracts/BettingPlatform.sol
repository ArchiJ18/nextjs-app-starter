// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract BettingPlatform is Ownable, ReentrancyGuard {
    struct Bet {
        address creator;
        string description;
        uint256 minBetAmount;
        uint256[] optionPools;
        mapping(uint256 => mapping(address => uint256)) userBets;
        mapping(address => bool) hasValidated;
        uint256 validationCount;
        uint256 winningOption;
        bool isResolved;
        uint256 totalPool;
        uint256 createdAt;
        uint256 validationFee;
        IERC20 token;
    }

    uint256 public constant MIN_BET_AMOUNT = 0.01 ether;
    uint256 public constant BURN_PERCENTAGE = 1;
    uint256 public constant PLATFORM_FEE = 25; // 2.5%
    uint256 public constant VALIDATION_THRESHOLD = 3;
    uint256 public constant MAX_OPTIONS = 5;
    uint256 public constant MIN_OPTIONS = 2;

    mapping(uint256 => Bet) public bets;
    uint256 public betCount;

    // Supported tokens
    mapping(address => bool) public supportedTokens;

    event BetCreated(uint256 indexed betId, address creator, string description, address token);
    event BetPlaced(uint256 indexed betId, address user, uint256 option, uint256 amount);
    event BetValidated(uint256 indexed betId, address validator, uint256 option);
    event BetResolved(uint256 indexed betId, uint256 winningOption);

    constructor() {
        _transferOwnership(msg.sender);
        // Initialize supported tokens (USDT and meme tokens)
        // Add actual token addresses for BSC mainnet
        supportedTokens[address(0x55d398326f99059fF775485246999027B3197955)] = true; // USDT
        supportedTokens[address(0x6982508145454Ce325dDbE47a25d4ec3d2311933)] = true; // PEPE
        // Add other supported tokens
    }

    function createBet(
        string memory description,
        uint256 numOptions,
        address tokenAddress,
        uint256 validationFee
    ) external returns (uint256) {
        require(numOptions >= MIN_OPTIONS && numOptions <= MAX_OPTIONS, "Invalid number of options");
        require(supportedTokens[tokenAddress], "Token not supported");

        uint256 betId = betCount++;
        Bet storage newBet = bets[betId];
        newBet.creator = msg.sender;
        newBet.description = description;
        newBet.minBetAmount = MIN_BET_AMOUNT;
        newBet.optionPools = new uint256[](numOptions);
        newBet.createdAt = block.timestamp;
        newBet.validationFee = validationFee;
        newBet.token = IERC20(tokenAddress);

        emit BetCreated(betId, msg.sender, description, tokenAddress);
        return betId;
    }

    function placeBet(uint256 betId, uint256 option, uint256 amount) external nonReentrant {
        Bet storage bet = bets[betId];
        require(!bet.isResolved, "Bet is resolved");
        require(option < bet.optionPools.length, "Invalid option");
        require(amount >= bet.minBetAmount, "Amount below minimum");

        uint256 burnAmount = (amount * BURN_PERCENTAGE) / 100;
        uint256 platformFee = (amount * PLATFORM_FEE) / 1000;
        uint256 betAmount = amount - burnAmount - platformFee;

        bet.token.transferFrom(msg.sender, address(this), amount);
        bet.token.transfer(address(0), burnAmount); // Burn
        bet.token.transfer(owner(), platformFee); // Platform fee

        bet.userBets[option][msg.sender] += betAmount;
        bet.optionPools[option] += betAmount;
        bet.totalPool += betAmount;

        emit BetPlaced(betId, msg.sender, option, amount);
    }

    function validateResult(uint256 betId, uint256 option) external nonReentrant {
        Bet storage bet = bets[betId];
        require(!bet.isResolved, "Bet already resolved");
        require(!bet.hasValidated[msg.sender], "Already validated");
        require(option < bet.optionPools.length, "Invalid option");

        bet.token.transferFrom(msg.sender, address(this), bet.validationFee);
        bet.hasValidated[msg.sender] = true;
        bet.validationCount++;

        if (bet.validationCount >= VALIDATION_THRESHOLD) {
            bet.winningOption = option;
            bet.isResolved = true;
            distributePrizes(betId);
            emit BetResolved(betId, option);
        }

        emit BetValidated(betId, msg.sender, option);
    }

    function distributePrizes(uint256 betId) internal {
        Bet storage bet = bets[betId];
        uint256 winningPool = bet.optionPools[bet.winningOption];
        
        if (winningPool > 0) {
            uint256 totalPrize = bet.totalPool;
            for (uint256 i = 0; i < bet.optionPools.length; i++) {
                if (bet.userBets[bet.winningOption][msg.sender] > 0) {
                    uint256 userShare = (bet.userBets[bet.winningOption][msg.sender] * totalPrize) / winningPool;
                    bet.token.transfer(msg.sender, userShare);
                }
            }
        }
    }

    function getBetInfo(uint256 betId) external view returns (
        address creator,
        string memory description,
        uint256[] memory pools,
        bool isResolved,
        uint256 totalPool,
        address tokenAddress
    ) {
        Bet storage bet = bets[betId];
        return (
            bet.creator,
            bet.description,
            bet.optionPools,
            bet.isResolved,
            bet.totalPool,
            address(bet.token)
        );
    }

    function addSupportedToken(address tokenAddress) external onlyOwner {
        supportedTokens[tokenAddress] = true;
    }

    function removeSupportedToken(address tokenAddress) external onlyOwner {
        supportedTokens[tokenAddress] = false;
    }
}
