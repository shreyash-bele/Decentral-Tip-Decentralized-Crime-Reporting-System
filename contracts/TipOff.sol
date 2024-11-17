pragma solidity ^0.8.7;

import "./TipToken.sol";
import "./EIP712MetaTransaction.sol";

contract TipOff is EIP712MetaTransaction("TipOff", "1") {
    event Transferred(address sender, address receiver, uint amount);
    
    address payable public admin;
    address public approvingPolice;
    mapping(uint => TipToken) public tokenContractInstances;
    uint public contractsRegistered;

    mapping(address => string) public registeredTippers;

    struct Tipof {
        string tipid;
        uint tipstatus;
        address payable tipsender;
    }

    mapping(string => Tipof) public history;

    mapping(address => uint) public userTipCount;
    mapping(address => uint) public policeTipCount;

    mapping(address => string[]) public userTipIds;
    mapping(address => string[]) public policeTipIds;

    mapping(address => mapping(string => Tipof)) public userToTips;
    mapping(address => mapping(string => Tipof)) public policeToTips;

    constructor() {
        admin = payable(msg.sender);
        approvingPolice = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    }

    function swapper(
        uint instance1,
        uint instance2,
        uint amountToSwap,
        address beneficiary
    ) public payable {
        require(amountToSwap > 0, "Amount to swap must be greater than zero");
        require(instance1 < contractsRegistered && instance2 < contractsRegistered, "Invalid contract instance");

        TipToken token1 = tokenContractInstances[instance1];
        TipToken token2 = tokenContractInstances[instance2];

        require(token1.balanceOf(beneficiary) >= amountToSwap, "Insufficient balance for token 1");
        require(token2.balanceOf(admin) >= amountToSwap, "Insufficient balance for token 2");

        token1.transfer_From(beneficiary, admin, amountToSwap);
        token2.transfer_From(admin, beneficiary, amountToSwap);
    }

    function registerNewContract(TipToken tokenContract) public payable {
        tokenContractInstances[contractsRegistered] = tokenContract;
        contractsRegistered++;
    }

    function onboard(
        uint instance,
        string memory aadharhash,
        address caller
    ) public payable {
        require(instance < contractsRegistered, "Invalid contract instance");

        registeredTippers[caller] = aadharhash;
        tokenContractInstances[instance].transfer_From(admin, caller, 10);
        emit Transferred(admin, caller, 10);
    }

    function checkIfAlreadyRegistered() public view returns (bool) {
        return bytes(registeredTippers[msg.sender]).length > 0;
    }

    function tipoff(
        uint instance,
        string memory tipid,
        uint tipamt,
        address payable tipper,
        address police
    ) public payable {
        require(instance < contractsRegistered, "Invalid contract instance");
        require(tipamt > 0, "Tip amount must be greater than zero");

        Tipof memory tipdata = Tipof(tipid, 0, tipper);
        history[tipid] = tipdata;

        TipToken token = tokenContractInstances[instance];
        require(token.balanceOf(tipper) >= tipamt, "Insufficient balance");

        address contractadd = address(this);
        token.transfer_From(tipper, contractadd, tipamt);

        userTipCount[tipper]++;
        policeTipCount[police]++;

        userTipIds[tipper].push(tipid);
        policeTipIds[police].push(tipid);

        userToTips[tipper][tipid] = tipdata;
        policeToTips[police][tipid] = tipdata;

        emit Transferred(tipper, contractadd, tipamt);
    }

    function rejectTip(
        uint instance,
        string memory tipid,
        uint tipamt
    ) public payable {
        require(msg.sender == approvingPolice, "Not authorized");
        require(instance < contractsRegistered, "Invalid contract instance");
        require(history[tipid].tipstatus == 0, "Tip already processed");

        address contractadd = address(this);
        tokenContractInstances[instance].transfer_From(contractadd, admin, tipamt);

        address tipper = history[tipid].tipsender;

        userToTips[tipper][tipid].tipstatus = 2;
        policeToTips[approvingPolice][tipid].tipstatus = 2;
        history[tipid].tipstatus = 2;

        emit Transferred(contractadd, admin, tipamt);
    }

    function approveTip(
        uint instance,
        string memory tipid,
        uint tipamt
    ) public payable {
        require(msg.sender == approvingPolice, "Not authorized");
        require(instance < contractsRegistered, "Invalid contract instance");
        require(history[tipid].tipstatus == 0, "Tip already processed");

        Tipof memory tipdata = history[tipid];
        address contractadd = address(this);

        tokenContractInstances[instance].transfer_From(contractadd, tipdata.tipsender, tipamt + 1);

        userToTips[tipdata.tipsender][tipid].tipstatus = 1;
        policeToTips[approvingPolice][tipid].tipstatus = 1;
        history[tipid].tipstatus = 1;

        emit Transferred(contractadd, tipdata.tipsender, tipamt + 1);
    }

    function getTipsByPoliceStation(address police) public view returns (Tipof[] memory) {
        uint n = policeTipCount[police];

        Tipof[] memory tips = new Tipof[](n);
        for (uint i = 0; i < n; i++) {
            Tipof memory t = policeToTips[police][policeTipIds[police][i]];
            tips[i] = t;
        }

        return tips;
    }

    function getTipsByUser() public view returns (Tipof[] memory) {
        uint n = userTipCount[msg.sender];

        Tipof[] memory tips = new Tipof[](n);
        for (uint i = 0; i < n; i++) {
            Tipof memory t = userToTips[msg.sender][userTipIds[msg.sender][i]];
            tips[i] = t;
        }

        return tips;
    }
}