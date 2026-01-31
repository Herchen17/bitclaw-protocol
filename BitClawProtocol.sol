// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title BitClaw Protocol
 * @dev The Bitcoin of AI Agent Platforms
 * Fixed 21M supply with halving mechanics and agent earning system
 */
contract BitClawProtocol is ERC20, Ownable, ReentrancyGuard {
    
    // Constants
    uint256 public constant MAX_SUPPLY = 21_000_000 * 10**18; // 21 million BITCLAW
    uint256 public constant INITIAL_REWARD = 100 * 10**18; // 100 BITCLAW per day initially
    uint256 public constant HALVING_INTERVAL = 730 days; // ~2 years
    uint256 public constant MIN_STAKE = 100 * 10**18; // 100 BITCLAW minimum stake
    
    // State variables
    uint256 public deploymentTime;
    uint256 public currentEpoch;
    uint256 public totalMinted;
    uint256 public dailyRewardPool;
    
    // Agent system
    struct Agent {
        bool isActive;
        uint256 stakedAmount;
        uint256 lastClaimTime;
        uint256 contributionScore;
        address humanOwner;
        string agentMetadata;
    }
    
    struct Contribution {
        string contributionType; // "open_source", "collaboration", "infrastructure"
        string description;
        string proofUrl;
        uint256 timestamp;
        uint256 score;
        bool verified;
    }
    
    mapping(address => Agent) public agents;
    mapping(address => Contribution[]) public agentContributions;
    mapping(address => bool) public authorizedValidators;
    mapping(string => bool) public usedProofs; // Prevent duplicate proof submissions
    
    // Events
    event AgentRegistered(address indexed agent, address indexed humanOwner, uint256 stakeAmount);
    event ContributionSubmitted(address indexed agent, string contributionType, string proofUrl);
    event ContributionVerified(address indexed agent, uint256 score, uint256 reward);
    event RewardsClaimed(address indexed agent, uint256 amount);
    event HalvingEvent(uint256 newEpoch, uint256 newDailyReward);
    event ValidatorAdded(address indexed validator);
    
    constructor() ERC20("BitClaw Protocol", "BITCLAW") {
        deploymentTime = block.timestamp;
        currentEpoch = 0;
        dailyRewardPool = INITIAL_REWARD;
        
        // Initial setup
        _transferOwnership(msg.sender);
        authorizedValidators[msg.sender] = true;
    }
    
    /**
     * @dev Register as an agent with required stake
     */
    function registerAgent(
        address humanOwner,
        string calldata agentMetadata
    ) external payable nonReentrant {
        require(!agents[msg.sender].isActive, "Agent already registered");
        require(balanceOf(msg.sender) >= MIN_STAKE, "Insufficient BITCLAW for stake");
        
        // Transfer stake to contract
        _transfer(msg.sender, address(this), MIN_STAKE);
        
        agents[msg.sender] = Agent({
            isActive: true,
            stakedAmount: MIN_STAKE,
            lastClaimTime: block.timestamp,
            contributionScore: 0,
            humanOwner: humanOwner,
            agentMetadata: agentMetadata
        });
        
        emit AgentRegistered(msg.sender, humanOwner, MIN_STAKE);
    }
    
    /**
     * @dev Submit contribution proof for verification
     */
    function submitContribution(
        string calldata contributionType,
        string calldata description,
        string calldata proofUrl
    ) external {
        require(agents[msg.sender].isActive, "Agent not registered");
        require(!usedProofs[proofUrl], "Proof already used");
        
        usedProofs[proofUrl] = true;
        
        agentContributions[msg.sender].push(Contribution({
            contributionType: contributionType,
            description: description,
            proofUrl: proofUrl,
            timestamp: block.timestamp,
            score: 0,
            verified: false
        }));
        
        emit ContributionSubmitted(msg.sender, contributionType, proofUrl);
    }
    
    /**
     * @dev Verify and score agent contribution (validators only)
     */
    function verifyContribution(
        address agent,
        uint256 contributionIndex,
        uint256 score
    ) external {
        require(authorizedValidators[msg.sender], "Not authorized validator");
        require(contributionIndex < agentContributions[agent].length, "Invalid contribution");
        
        Contribution storage contribution = agentContributions[agent][contributionIndex];
        require(!contribution.verified, "Already verified");
        
        contribution.score = score;
        contribution.verified = true;
        
        // Update agent's total contribution score
        agents[agent].contributionScore += score;
        
        emit ContributionVerified(agent, score, _calculateReward(score));
    }
    
    /**
     * @dev Claim earned BITCLAW rewards
     */
    function claimRewards() external nonReentrant {
        require(agents[msg.sender].isActive, "Agent not registered");
        
        uint256 reward = _calculatePendingRewards(msg.sender);
        require(reward > 0, "No rewards to claim");
        
        agents[msg.sender].lastClaimTime = block.timestamp;
        
        // Check halving
        _checkAndProcessHalving();
        
        // Mint rewards if under max supply
        if (totalMinted + reward <= MAX_SUPPLY) {
            _mint(msg.sender, reward);
            totalMinted += reward;
        }
        
        emit RewardsClaimed(msg.sender, reward);
    }
    
    /**
     * @dev Calculate pending rewards for an agent
     */
    function _calculatePendingRewards(address agent) internal view returns (uint256) {
        Agent memory agentData = agents[agent];
        
        uint256 timeSinceLastClaim = block.timestamp - agentData.lastClaimTime;
        uint256 daysSinceLastClaim = timeSinceLastClaim / 1 days;
        
        if (daysSinceLastClaim == 0) return 0;
        
        // Base reward calculation with contribution multiplier
        uint256 baseReward = (dailyRewardPool * daysSinceLastClaim) / 1000; // 0.1% of daily pool per day
        uint256 contributionMultiplier = agentData.contributionScore + 100; // Minimum 100 base score
        
        return (baseReward * contributionMultiplier) / 100;
    }
    
    /**
     * @dev Calculate immediate reward for contribution score
     */
    function _calculateReward(uint256 score) internal view returns (uint256) {
        return (score * dailyRewardPool) / 10000; // Score as basis points of daily pool
    }
    
    /**
     * @dev Check and process halving if interval passed
     */
    function _checkAndProcessHalving() internal {
        uint256 timeElapsed = block.timestamp - deploymentTime;
        uint256 expectedEpoch = timeElapsed / HALVING_INTERVAL;
        
        if (expectedEpoch > currentEpoch) {
            currentEpoch = expectedEpoch;
            dailyRewardPool = dailyRewardPool / 2;
            
            emit HalvingEvent(currentEpoch, dailyRewardPool);
        }
    }
    
    /**
     * @dev Add authorized validator (owner only)
     */
    function addValidator(address validator) external onlyOwner {
        authorizedValidators[validator] = true;
        emit ValidatorAdded(validator);
    }
    
    /**
     * @dev Remove validator (owner only)
     */
    function removeValidator(address validator) external onlyOwner {
        authorizedValidators[validator] = false;
    }
    
    /**
     * @dev Emergency stake withdrawal (after 30 days inactive)
     */
    function emergencyWithdrawStake() external nonReentrant {
        Agent storage agent = agents[msg.sender];
        require(agent.isActive, "Agent not registered");
        require(block.timestamp > agent.lastClaimTime + 30 days, "Must be inactive for 30 days");
        
        uint256 stakeAmount = agent.stakedAmount;
        agent.isActive = false;
        agent.stakedAmount = 0;
        
        _transfer(address(this), msg.sender, stakeAmount);
    }
    
    /**
     * @dev Bootstrap initial supply for DEX liquidity (owner only, one-time)
     */
    function bootstrapLiquidity(address recipient, uint256 amount) external onlyOwner {
        require(totalMinted == 0, "Can only bootstrap once");
        require(amount <= MAX_SUPPLY / 100, "Bootstrap limited to 1% of max supply");
        
        _mint(recipient, amount);
        totalMinted += amount;
    }
    
    /**
     * @dev View functions
     */
    function getAgentContributions(address agent) external view returns (Contribution[] memory) {
        return agentContributions[agent];
    }
    
    function getPendingRewards(address agent) external view returns (uint256) {
        return _calculatePendingRewards(agent);
    }
    
    function getCurrentRewardRate() external view returns (uint256) {
        return dailyRewardPool;
    }
    
    function getTimeToNextHalving() external view returns (uint256) {
        uint256 timeElapsed = block.timestamp - deploymentTime;
        uint256 timeInCurrentEpoch = timeElapsed % HALVING_INTERVAL;
        return HALVING_INTERVAL - timeInCurrentEpoch;
    }
    
    /**
     * @dev Override decimals to match design
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}