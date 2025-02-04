// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TokenManager {
    // Токен параметры
    string public name = "MyToken";
    string public symbol = "MTK";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    // Балансы и разрешения
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Структура делегатов
    struct Delegate {
        address addr;
        uint256 votes;
        bool isWitness;
    }

    // Хранение делегатов и свидетелей
    mapping(address => Delegate) public delegates;
    address[] public witnesses;
    uint256 public maxWitnesses = 10;
    uint256 public lastElectionTime;
    uint256 public electionInterval = 7 days;

    // События
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event WitnessElected(address indexed witness);
    event WitnessDowngraded(address indexed witness);

    constructor(uint256 _initialSupply) payable {
    require(msg.value > 0, "ETH must be sent to deploy contract");  // Проверяем, что ETH передан
    totalSupply = _initialSupply * (10 ** decimals);
    balanceOf[msg.sender] = totalSupply;
    }
    receive() external payable {
    // Просто принимает и хранит ETH
    }

    function getContractBalance() public view returns (uint256) {
    return address(this).balance;
    }
    function withdrawETH() public {
    payable(msg.sender).transfer(address(this).balance);
    }

    modifier onlyWitness() {
        require(delegates[msg.sender].isWitness, "Only witnesses can perform this action");
        _;
    }

    // Функция для голосования за делегата
    function voteForDelegate(address _delegate) public {
        require(balanceOf[msg.sender] > 0, "You must hold tokens to vote");
        require(_delegate != address(0), "Invalid delegate address");
        
        delegates[_delegate].votes += balanceOf[msg.sender];
    }

    // Выборы свидетелей
    function electWitnesses() public {
        require(block.timestamp >= lastElectionTime + electionInterval, "Election not yet due");

        // Очистка списка свидетелей
        delete witnesses;

        // Получение топ-делегатов по голосам
        address[] memory sortedDelegates = getTopDelegates();

        for (uint256 i = 0; i < maxWitnesses && i < sortedDelegates.length; i++) {
            witnesses.push(sortedDelegates[i]);
            delegates[sortedDelegates[i]].isWitness = true;
            emit WitnessElected(sortedDelegates[i]);
        }

        lastElectionTime = block.timestamp;
    }

    // Внутренний перевод токенов
    function _transfer(address _from, address _to, uint256 _value) internal {
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(_to != address(0), "Invalid recipient address");

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);
    }

    // Перевод токенов свидетелем
    function witnessTransfer(address _to, uint256 _value) public onlyWitness returns (bool) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    // Понижение свидетеля
    function downgradeWitness(address _witness) public onlyWitness {
        require(delegates[_witness].isWitness, "Address is not a witness");

        delegates[_witness].isWitness = false;
        removeWitness(_witness);

        address newWitness = selectNewWitness();
        if (newWitness != address(0)) {
            witnesses.push(newWitness);
            delegates[newWitness].isWitness = true;
            emit WitnessElected(newWitness);
        }

        emit WitnessDowngraded(_witness);
    }

    // Удаление свидетеля из массива
    function removeWitness(address _witness) internal {
        for (uint256 i = 0; i < witnesses.length; i++) {
            if (witnesses[i] == _witness) {
                witnesses[i] = witnesses[witnesses.length - 1];
                witnesses.pop();
                break;
            }
        }
    }

    // Выбор нового свидетеля из делегатов
    function selectNewWitness() internal view returns (address) {
        address[] memory sortedDelegates = getTopDelegates();
        for (uint256 i = 0; i < sortedDelegates.length; i++) {
            if (!delegates[sortedDelegates[i]].isWitness) {
                return sortedDelegates[i];
            }
        }
        return address(0);
    }

    // Получение списка топ-делегатов по количеству голосов (сортировка)
    function getTopDelegates() internal view returns (address[] memory) {
        address[] memory delegateList = new address[](maxWitnesses);
        uint256 count = 0;

        // Заполнение массива голосами
        for (uint256 i = 0; i < maxWitnesses; i++) {
            if (delegates[delegateList[i]].votes > 0) {
                delegateList[count] = delegateList[i];
                count++;
            }
        }

        // Сортировка делегатов по количеству голосов (упрощенный пузырьковый метод)
        for (uint256 i = 0; i < count; i++) {
            for (uint256 j = i + 1; j < count; j++) {
                if (delegates[delegateList[i]].votes < delegates[delegateList[j]].votes) {
                    (delegateList[i], delegateList[j]) = (delegateList[j], delegateList[i]);
                }
            }
        }

        // Возвращаем отсортированный список делегатов
        address[] memory sortedDelegates = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            sortedDelegates[i] = delegateList[i];
        }

        return sortedDelegates;
    }

    // Разрешение на перевод токенов
    function approve(address _spender, uint256 _value) public returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    // Перевод токенов с разрешением
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(allowance[_from][msg.sender] >= _value, "Allowance exceeded");
        require(balanceOf[_from] >= _value, "Insufficient balance");

        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

    // Прямой перевод токенов между пользователями
    function transfer(address _to, uint256 _value) public returns (bool) {
        _transfer(msg.sender, _to, _value);
        return true;
    }
    
}
