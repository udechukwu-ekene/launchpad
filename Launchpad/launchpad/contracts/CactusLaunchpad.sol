//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/ICactusToken.sol";

contract CactusLaunchpad is Ownable {
    using SafeMath for uint256;

    ICactusToken public cactt;

    bool public isClosed = false;

    mapping(address => bool) public operators;
    mapping(address => HolderInfo) private _launchpadInfo;

    address[] private _launchpad;
    address public payableAddress;

    uint256 public cacttSold;
    uint256 public hardCap = 3e6 * 10**18; //3,000,000
    uint256 public constant CACTT_PER_BNB = 6000;
    uint256 public constant MIN_CONTRIBUTION = 100000000000000000;
    uint256 public constant MAX_CONTRIBUTION = 10000000000000000000;

    uint256 public endTime = 1652659200; // 2022-05-09 00:00:00
    uint256 public startTime = 1652054400; // 2022-05-16 00:00:00
    uint256 private _newPaymentInterval = 2592000;

    struct HolderInfo {
        uint256 totalContribution;
        uint256 monthlyCredit;
        uint256 amountLocked;
        uint256 nextPaymentUntil;
    }

    event CloseSale(bool indexed closed);

    constructor(ICactusToken _cactt, address _payableAddress) {
        cactt = _cactt;
        payableAddress = _payableAddress;
        operators[owner()] = true;
        emit OperatorUpdated(owner(), true);
    }

    modifier onlyOperator() {
        require(operators[msg.sender], "caller is not the operator");
        _;
    }

    event OperatorUpdated(address indexed operator, bool indexed status);
    event Contributed(address indexed sender, uint256 indexed value);

    function totalContributors() public view returns (uint256) {
      return _launchpad.length;
    }

    function balance() public view returns (uint256) {
        return cactt.balanceOf(address(this));
    }

    function burn(uint256 amount) public onlyOperator {
        cactt.burn(address(this), amount);
    }

    function setCACTT(ICactusToken _newCactt) public onlyOperator {
        cactt = _newCactt;
    }

    function contribute() public payable {
        require(block.timestamp > startTime, "Sale is not yet live");
        require(block.timestamp < endTime && !isClosed, "Sale is closed");
        require(msg.value >= MIN_CONTRIBUTION, "Min sale is 0.1 BNB");
        require(msg.value <= MAX_CONTRIBUTION, "MAX purchase is 10BNB");

        uint256 _cacttAmount = msg.value * CACTT_PER_BNB;
        cacttSold = cacttSold.add(_cacttAmount);

        require(hardCap >= cacttSold, "Hard cap reached");
        payable(payableAddress).transfer(msg.value);

        uint256 initialPayment = _cacttAmount.div(5).mul(3); // Release 60% of payment
        uint256 credit = _cacttAmount.sub(initialPayment);

        HolderInfo memory holder = _launchpadInfo[msg.sender];
        if (holder.totalContribution <= 0) {
            _launchpad.push(msg.sender);
        }

        holder.totalContribution = holder.totalContribution.add(_cacttAmount);
        holder.amountLocked = holder.amountLocked.add(credit);
        holder.monthlyCredit = holder.amountLocked.div(4); // divide amount locked to 4 months
        holder.nextPaymentUntil = block.timestamp.add(_newPaymentInterval);
        _launchpadInfo[msg.sender] = holder;

        if (hardCap == cacttSold) {
            _closeSale();
        }

        cactt.transfer(msg.sender, initialPayment);

        emit Contributed(msg.sender, msg.value);
    }

    function timelyPaymentRelease() public onlyOperator {
        for (uint256 i = 0; i < _launchpad.length; i++) {
            HolderInfo memory holder = _launchpadInfo[_launchpad[i]];
            if (
                holder.amountLocked > 0 &&
                block.timestamp >= holder.nextPaymentUntil
            ) {
                holder.amountLocked = holder.amountLocked.sub(
                    holder.monthlyCredit
                );
                holder.nextPaymentUntil = block.timestamp.add(
                    _newPaymentInterval
                );
                _launchpadInfo[_launchpad[i]] = holder;
                cactt.transfer(_launchpad[i], holder.monthlyCredit);
            }
        }
    }

    function _closeSale() internal {
        require(block.timestamp < endTime && !isClosed, "Sale is closed");
        isClosed = true;
        emit CloseSale(true);
    }

    function setEndTime(uint256 _endTime) public onlyOperator {
        endTime = _endTime;
        isClosed = false;
    }

    function closeSale() public onlyOperator {
        _closeSale();
    }

    function getHolderInfo(address _holder)
        public
        view
        returns (HolderInfo memory)
    {
        return _launchpadInfo[_holder];
    }

    function updateOperator(address _operator, bool _status)
        public
        onlyOperator
    {
        operators[_operator] = _status;
        emit OperatorUpdated(_operator, _status);
    }
}
