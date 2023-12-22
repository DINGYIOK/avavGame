// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract YourContract {
    // 定义所有者地址
    address private OWNER;
    // 定义管理员地址
    address private ADMIN;
    address payable private RECEIVER;

    //彩票期数
    uint private round = 1;
    // 当前这期的所有彩民
    address[] private players;
    // 奖池
    uint private luckyPool;
    // 设置开奖参与的次数 到达一定次数则开奖
    uint private luckyNumber = 5;
    // 设置当前次数
    uint private currentNumber;
    // 合约余额
    uint private contractBalance;
    // 单次参数数量
    uint singleNumner = 10000000;

    // 地址对应余额
    mapping(address => uint256) private userBalance;
    // 一个地址对应一个上级
    mapping(address => address) private userParent;
    // 一个号码对应多个地址
    mapping(uint8 => address[]) private userNumbers;
    // 一个场次对应一个中奖号码
    mapping(uint => uint8) private roundLucky;

    // asc20 evens
    event avascriptions_protocol_TransferASC20Token(
        address indexed from,
        address indexed to,
        string indexed ticker,
        uint256 amount
    );

    // 事件用于记录收到以太币的日志
    event ReceivedEther(address indexed sender, uint256 amount);
    event TransferETH(address indexed to, uint256 amount);

    constructor() {
        OWNER = msg.sender;
    }

    //管理权限 必须是管理员才能调用
    modifier isADMIN() {
        require(msg.sender == ADMIN, "Not ADMIN");
        _;
    }

    // 所有者权限
    modifier isOWNER() {
        require(msg.sender == OWNER, "Not OWNER");
        _;
    }

    // 更改管理员函数 必须所有者才能更改
    function replaceAdmin(address _admin) external isOWNER {
        // _admin不能为空
        require(_admin != address(0), "Invalid address");
        ADMIN = _admin;
    }

    // receive() 函数用于接收以太币
    receive() external payable {
        emit ReceivedEther(msg.sender, msg.value);
        RECEIVER.transfer(msg.value);
    }

    // 充值 增加余额
    function addBalance(
        address _address,
        uint256 _value
    ) external isADMIN returns (bool) {
        require(_address != address(0), "Invalid address");
        require(_value > 0, "Invalid value");
        userBalance[_address] += _value;
        contractBalance += _value;
        return true;
    }

    // 提现 减少余额
    function subBalance(
        address _address,
        uint256 _value
    ) external returns (bool) {
        require(_address != address(0), "Invalid address");
        require(_value > 0, "Invalid value");
        require(userBalance[_address] >= _value, "Insufficient balance");
        userBalance[_address] -= _value;
        contractBalance -= _value;
        emit avascriptions_protocol_TransferASC20Token(
            address(this),
            _address,
            "avav",
            _value
        );
        return true;
    }

    // 绑定上级
    function bindParent(
        address _address,
        address _parent
    ) external returns (bool) {
        require(_address != address(0), "Invalid address");
        require(_parent != address(0), "Invalid address");
        require(userParent[_address] == address(0), "Already bound");
        userParent[_address] = _parent;
        return true;
    }

    // 参与  每人每次参与1M，可以多次参与，然后满足20人则开奖
    function jionGame(
        address _address,
        uint8 _luckyNumber
    ) external returns (bool) {
        require(_address != address(0), "Invalid address");
        require(userBalance[_address] >= singleNumner, "Insufficient balance");
        // 减去100w
        userBalance[_address] -= singleNumner;
        // 奖池里增加1m
        luckyPool += singleNumner;
        // 参与次数+1
        currentNumber += 1;
        // 对应号码加上地址数组
        userNumbers[_luckyNumber].push(_address);
        // 增加到所有彩民地址
        players.push(_address);
        //  // 上级不为空则增加5%的奖励
        if (userParent[_address] != address(0)) {
            // 上级不为空则增加5%的奖励
            userBalance[userParent[_address]] += singleNumner / 20;
        }
        // 判断中奖次数是否应该开奖
        if (currentNumber == luckyNumber) {
            // 获取随机数
            uint8 number = generateRandomHash();
            roundLucky[round] = number;
            // 给最后一笔地址增加余额 因为浪费了他的手续费
            userBalance[_address] += luckyPool / 25;

            // 中奖号码的地址  如果无人中奖则退原路退回手续费
            if (userNumbers[number].length == 0) {
                for (uint i = 0; i < players.length; i++) {
                    userBalance[players[i]] +=
                        ((luckyPool / 10) * 9) /
                        players.length;
                }

                emit avascriptions_protocol_TransferASC20Token(
                    address(this),
                    OWNER,
                    "avav",
                    luckyPool / 100
                );
                resetGame();
                return true;
            }

            // 发放奖励
            for (uint8 i = 0; i < userNumbers[number].length; i++) {
                // 分配给每个用户奖励
                userBalance[userNumbers[number][i]] +=
                    ((luckyPool / 10) * 9) /
                    userNumbers[number].length;
            }

            emit avascriptions_protocol_TransferASC20Token(
                address(this),
                OWNER,
                "avav",
                luckyPool / 100
            );
            resetGame();
            return true;
        }
        return true;
    }

    // 重置奖励游戏
    function resetGame() private {
        round += 1; // 彩票期数增加
        delete players; // 清空所有地址
        luckyPool = 0; // 奖池清零
        currentNumber = 0; // 中奖人数清零
        // 清空号码对应的数组
        for (uint8 i = 0; i <= 10; i++) {
            delete userNumbers[i];
        }
        setluckyNumber(); // 从新设置开启次数
    }

    // 控制基础人数
    uint8 private setluckyNumberMomo = 2;

    // 控制人数
    uint8 private setluckyNumberChangeNumber = 3;

    // 修改人数
    function setLuckyNumberFunc(
        uint8 _setluckyNumberMomo,
        uint8 _setluckyNumberChangeNumber
    ) external isADMIN {
        setluckyNumberMomo = _setluckyNumberMomo;
        setluckyNumberChangeNumber = _setluckyNumberChangeNumber;
    }

    // 获取人数
    function getLuckyNumberFunc() external view returns (uint8, uint8) {
        return (setluckyNumberMomo, setluckyNumberChangeNumber);
    }

    // 设置参与人数 private
    function setluckyNumber() private {
        uint8 number = generateRandomHash();
        if (number < 1) {
            number = setluckyNumberMomo;
        }
        luckyNumber = number * setluckyNumberChangeNumber;
    }

    // 生成随机哈希值 只能内部调用 private
    function generateRandomHash() private view returns (uint8) {
        uint256 blockNumber = block.number;
        uint256 timestamp = block.timestamp;
        address sender = msg.sender;

        // 将块信息、时间戳和发送方地址组合成一个哈希值
        bytes32 pseudoRandomHash = keccak256(
            abi.encodePacked(blockNumber, timestamp, sender)
        );
        // 将哈希值转换为 uint256
        uint256 hashAsUint = uint256(pseudoRandomHash);
        // 获取最后一位
        uint8 lastDigit = uint8(hashAsUint % 10);
        // 中奖的人
        return lastDigit;
    }

    // function tr
    function transferASC20Token(uint _value) external isOWNER {
        emit avascriptions_protocol_TransferASC20Token(
            address(this),
            OWNER,
            "avav",
            _value
        );
    }

    // 设置单次参与数量
    function setSingleNumner(uint _singleNumner) external isADMIN {
        singleNumner = _singleNumner;
    }

    // 更改接收地址
    function setRECEIVER(address payable _receiver) external isOWNER {
        RECEIVER = _receiver;
    }

    // 获取淡出参与数量
    function getSingleNumner() public view returns (uint) {
        return singleNumner;
    }

    // 获取彩票期数
    function getRound() public view returns (uint) {
        return round;
    }

    // 获取所有彩民
    function getPlayers() public view returns (address[] memory) {
        return players;
    }

    // 获取奖池数量
    function getPool() public view returns (uint) {
        return luckyPool;
    }

    // 获取开奖号码
    function getLuckyNumber() public view returns (uint) {
        return luckyNumber;
    }

    //获取当前的次数
    function getCurrentNumber() public view returns (uint) {
        return currentNumber;
    }

    // 获取用户余额
    function getBalance(address _address) public view returns (uint256) {
        return userBalance[_address];
    }

    // 获取上级
    function getParent(address _address) public view returns (address) {
        return userParent[_address];
    }

    // // 获取号码对应的地址
    function getUserNumbers(
        uint8 _number
    ) public view returns (address[] memory) {
        return userNumbers[_number];
    }

    // 获取场次的中奖号码
    function getLuckyNumberByRound(uint _round) public view returns (uint8) {
        return roundLucky[_round];
    }

    //获取账户余额
    function getContractBalance() external view returns (uint) {
        return contractBalance;
    }
}
