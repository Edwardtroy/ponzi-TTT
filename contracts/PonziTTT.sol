pragma solidity ^0.4.11;


contract PonziTTT {

    // ================== Owner list ====================
    // list of owners
    address[256] owners;
    // list of trainees;
    address[] trainees;
    address[] traineesShouldRefund;
    // required lessons
    uint256 required;
    // index on the list of owners to allow reverse lookup
    mapping(address => uint256) ownerIndex;
    // ================== Owner list ====================

    // ================== Trainee list ====================
    // balance of the list of trainees to allow refund value
    mapping(address => uint256) traineeBalances;
    // ================== Trainee list ====================
    mapping(address => uint256) traineeProgress;

    uint256 startBlock = block.number;
    uint256 endBlock = block.number + 10000;
    uint256 onlyOneChanceToChangeEndTime = 1;

    // EVENTS

    // logged events:
    // Funds has arrived into the wallet (record how much).
    event Registration(address _from, uint256 _amount);
    event Confirmation(address _from, address _to, uint256 _lesson);
    // Funds has refund back (record how much).
    event Refund(address _from, address _to, uint256 _amount);
    event FallbackLog(address _from, uint256 _amount);
    event AutoRefundTrainee(address _from, address[] _refundlist, uint256 _amount);


    modifier onlyOwner {
        require(isOwner(msg.sender));
        _;
    }

    function isOwner(address _addr) constant returns (bool) {
        return ownerIndex[_addr] > 0;
    }

    modifier onlyTrainee {
        require(isTrainee(msg.sender));
        _;
    }

    modifier notTrainee {
        require(!isTrainee(msg.sender));
        _;
    }

    modifier beforeEnd { 
        require(isInTrainingProcess()); 
        _; 
    }

    modifier afterEnd { 
        require(!isInTrainingProcess()); 
        _; 
    }

    function isInTrainingProcess() constant returns (bool) {
        uint256 nowTime = block.number;
        return nowTime <= endBlock;
    }

    function isTrainee(address _addr) constant returns (bool) {
        return traineeBalances[_addr] > 0;
    }

    function isFinished(address _addr) constant returns (bool) {
        return traineeProgress[_addr] >= required;
    }

    function PonziTTT(address[] _owners, uint256 _required) {
        owners[1] = msg.sender;
        ownerIndex[msg.sender] = 1;
        required = _required;
        for (uint256 i = 0; i < _owners.length; ++i) {
            owners[2 + i] = _owners[i];
            ownerIndex[_owners[i]] = 2 + i;
        }
    }

    function() payable notTrainee {
        require(msg.value == 2 ether);
        traineeBalances[msg.sender] = msg.value;
        FallbackLog(msg.sender, msg.value);
    }

    function setEndBlock(uint256 timeFromStartToEnd) onlyOwner {
        require(onlyOneChanceToChangeEndTime > 0);
        endBlock = startBlock + timeFromStartToEnd;
        onlyOneChanceToChangeEndTime -= 1;
    }

    function getEndBlock() constant returns (uint256) {
        return endBlock;
    }

    function register() payable notTrainee beforeEnd {
        require(msg.value == 2 ether);
        traineeBalances[msg.sender] = msg.value;
        trainees.push(msg.sender);
        Registration(msg.sender, msg.value);
    }

    function balanceOf(address _addr) constant returns (uint256) {
        return traineeBalances[_addr];
    }

    function progressOf(address _addr) constant returns (uint256) {
        return traineeProgress[_addr];
    }

    function checkBalance() onlyTrainee constant returns (uint256) {
        return traineeBalances[msg.sender];
    }

    function checkProgress() onlyTrainee constant returns (uint256) {
        return traineeProgress[msg.sender];
    }

    function confirmOnce(address _recipient) onlyOwner beforeEnd {
        require(isTrainee(_recipient));
        traineeProgress[_recipient] = traineeProgress[_recipient] + 1;
        Confirmation(msg.sender, _recipient, traineeProgress[_recipient]);
    }

    function checkContractBalance() onlyOwner constant returns (uint256) {
        return this.balance;
    }

    function refund(address _recipient) onlyOwner afterEnd {
        require(isTrainee(_recipient));
        require(isFinished(_recipient));
        _recipient.transfer(traineeBalances[_recipient]);
        Refund(msg.sender, _recipient, traineeBalances[_recipient]);
        traineeBalances[_recipient] = 0;
    }

    function autoRefund() onlyOwner afterEnd {
        uint256 totalBalance = this.balance;
        uint256 averageBalance;

        for (uint256 index = 0; index < trainees.length; index++) {
            address trainee = trainees[index];
            if (isFinished(trainee)) {
                traineesShouldRefund.push(trainee);
            }
        }

        if (traineesShouldRefund.length > 0) {
            averageBalance = totalBalance / (traineesShouldRefund.length);

            for (uint256 i = 0; i < traineesShouldRefund.length; i++) {
                address traineeRefund = traineesShouldRefund[i];
                traineeRefund.transfer(averageBalance);
                traineeBalances[traineeRefund] = 0;
            }

            AutoRefundTrainee(msg.sender, traineesShouldRefund, averageBalance);
        }
    }

    function destroy() onlyOwner {
        selfdestruct(msg.sender);
    }

    function destroyTransfer(address _recipient) onlyOwner {
        selfdestruct(_recipient);
    }
}
