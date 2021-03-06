//"SPDX-License-Identifier: UNLICENSED"
pragma solidity ^0.6.12;

import "./math/SafeMath.sol";
import "./IERC20.sol";

/// ParticipationVesting smart contract
contract ParticipationVesting  {

    using SafeMath for *;

    struct Participation {
        uint256 initialPortion;
        uint256 vestedAmount;
        uint256 amountPerPortion;
        bool initialPortionWithdrawn;
        bool [] isVestedPortionWithdrawn;
    }

    IERC20 public token;

    address public adminWallet;
    mapping(address => Participation) public addressToParticipation;
    mapping(address => bool) public hasParticipated;

    uint public initialPortionUnlockingTime;
    uint public numberOfPortions;
    uint [] public distributionDates;

    // Percent initially unlocked for withdrawal
    uint public initiallyUnlockedPercent;

    modifier onlyAdmin {
        require(msg.sender == adminWallet, "OnlyAdmin: Restricted access.");
        _;
    }

    /// Load initial distribution dates
    constructor (
        uint _numberOfPortions,
        uint timeBetweenPortions,
        uint distributionStartDate,
        uint _initialPortionUnlockingTime,
        uint _initiallyUnlockedPercent,
        address _adminWallet,
        address _token
    )
    public
    {
        // Set admin wallet
        adminWallet = _adminWallet;
        // Store number of portions
        numberOfPortions = _numberOfPortions;
        // How many percent is unlocked at the beginning
        initiallyUnlockedPercent = _initiallyUnlockedPercent;
        // Time when initial portion is unlocked
        initialPortionUnlockingTime = _initialPortionUnlockingTime;

        // Set distribution dates
        for(uint i = 0 ; i < _numberOfPortions; i++) {
            distributionDates.push(distributionStartDate + i*timeBetweenPortions);
        }
        // Set the token address
        token = IERC20(_token);
    }

    /// Register participant
    function registerParticipant(
        address participant,
        uint participationAmount
    )
    external
    onlyAdmin
    {
        require(hasParticipated[participant] == false, "User already registered as participant.");
        // Compute initially unlocked percent
        uint initialPortionAmount = participationAmount.mul(initiallyUnlockedPercent).div(100);
        // Vested leftover
        uint vestedAmount = participationAmount.sub(initialPortionAmount);
        // Compute amount per portion
        uint portionAmount = vestedAmount.div(numberOfPortions);
        bool[] memory isPortionWithdrawn = new bool[](numberOfPortions);

        // Create new participation object
        Participation memory p = Participation({
        initialPortion: initialPortionAmount,
        vestedAmount: vestedAmount,
        amountPerPortion: portionAmount,
        initialPortionWithdrawn: false,
        isVestedPortionWithdrawn: isPortionWithdrawn
        });

        // Map user and his participation
        addressToParticipation[participant] = p;
        // Mark that user have participated
        hasParticipated[participant] = true;
    }


    // User will always withdraw everything available
    function withdraw()
    external
    {
        address user = msg.sender;
        require(hasParticipated[user] == true, "Withdraw: User is not a participant.");

        Participation storage p = addressToParticipation[user];

        uint256 totalToWithdraw = 0;

        // Initial portion can be withdrawn
        if(p.initialPortionWithdrawn == false && block.timestamp >= initialPortionUnlockingTime) {
            totalToWithdraw = totalToWithdraw.add(p.initialPortion);
            // Mark initial portion as withdrawn
            p.initialPortionWithdrawn = true;
        }

        uint i = 0;

        while (isPortionUnlocked(i) == true && i < distributionDates.length) {
            // If portion is not withdrawn
            if(!p.isVestedPortionWithdrawn[i]) {
                // Add this portion to withdraw amount
                totalToWithdraw = totalToWithdraw.add(p.amountPerPortion);

                // Mark portion as withdrawn
                p.isVestedPortionWithdrawn[i] = true;
            }
            // Increment counter
            i++;
        }

        // Transfer all tokens to user
        token.transfer(user, totalToWithdraw);
    }

    function isPortionUnlocked(uint portionId)
    public
    view
    returns (bool)
    {
        return block.timestamp >= distributionDates[portionId];
    }

}
