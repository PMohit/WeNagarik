pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Token.sol";

 

contract Government is Ownable {
    using SafeMath for uint256;


    
    address payable private _sovereign;
 
    Token private _token;

    uint256 private _price;

    
    struct Citizen {
        bool isAlive;  
        address employer; / 
        bool isWorking;
        bool isSick; 
        uint256 retirementDate; 
        uint256 currentTokens;  
        uint256 healthTokens;  
        uint256 unemploymentTokens;  
        uint256 retirementTokens; 
    }

     
    mapping(address => Citizen) private _citizens;

    
    mapping(address => bool) private _hospitals;

    
    mapping(address => bool) private _companies;

    
    uint256 constant RETIREMENT_AGE = 67;
    uint256 constant DENOMINATION = 10**18;
    uint256 constant AWARD_CITIZENSHIP = 100 * DENOMINATION;

    
    enum HealthStatus {Died, Healthy, Sick}

    
    event CreatedCitizen(
        address indexed citizenAddress,
        bool isAlive,
        address employer,
        bool isWorking,
        bool isSick,
        uint256 retirementDate,
        uint256 currentTokens,
        uint256 healthTokens,
        uint256 unemploymentTokens,
        uint256 retirementTokens
    );

   
    event LostCitizenship(address indexed citizenAddress);

    
    event UpdatedHealth(address indexed citizenAddress, bool isSick, uint256 currentTokens, uint256 healthTokens);

    
    event UpdatedEmployment(
        address indexed citizenAddress,
        address employer,
        bool isWorking,
        uint256 currentTokens,
        uint256 unemploymentTokens
    );

     
    event Retired(
        address indexed citizenAddress,
        address employer,
        bool isWorking,
        uint256 currentTokens,
        uint256 unemploymentTokens,
        uint256 retirementTokens
    );

     
    event SetHospital(address indexed hospital, bool isHospital);

     
    event SetCompany(address indexed company, bool isCompany);

    
    event Paid(
        address indexed citizenAddress,
        uint256 indexed amount,
        address indexed employer,
        uint256 currentTokens,
        uint256 healthTokens,
        uint256 unemploymentTokens,
        uint256 retirementTokens
    );

     
    constructor(address owner_, uint256 priceFull) public {
        transferOwnership(owner_);
        _price = priceFull;
        _sovereign = payable(owner());
    }

    // Modifiers
 
    modifier onlyHospitals() {
        require(_hospitals[msg.sender] == true, "Government: only a hospital can perform this action");
        _;
    }

   
    modifier onlyCompanies() {
        require(_companies[msg.sender] == true, "Government: only a company can perform this action");
        _;
    }

    
    modifier onlyAliveCitizens() {
        require(_citizens[msg.sender].isAlive == true, "Government: only alive citizens can perform this action");
        _;
    }

   
    function _cancelCitizen(address formerCitizen) private {
        _citizens[formerCitizen].isAlive = false;
        _citizens[formerCitizen].employer = address(0);
        _citizens[formerCitizen].isWorking = false;
        _citizens[formerCitizen].isSick = false;
        _citizens[formerCitizen].retirementDate = 0;
        _citizens[formerCitizen].currentTokens = 0;
        _citizens[formerCitizen].healthTokens = 0;
        _citizens[formerCitizen].unemploymentTokens = 0;
        _citizens[formerCitizen].retirementTokens = 0;
        _token.operatorSend(formerCitizen, _sovereign, _token.balanceOf(formerCitizen), "", "");
        LostCitizenship(formerCitizen);
    }

     
    function getCitizen(address citizenAddress) public view returns (Citizen memory) {
        return _citizens[citizenAddress];
    }

    
    function getToken() public view returns (address) {
        return address(_token);
    }

    
    function sovereign() public view returns (address payable) {
        return _sovereign;
    }
 
    function price() public view returns (uint256) {
        return _price;
    }

     
    function checkHospital(address hospitalAddress) public view returns (bool) {
        return _hospitals[hospitalAddress];
    }

    
    function checkCompany(address companyAddress) public view returns (bool) {
        return _companies[companyAddress];
    }

  

    
    function setToken() external {
        require(address(_token) == address(0), "Government: token address must be address 0");
        _token = Token(msg.sender);
    }

    
    function denaturalize(address sentenced) public onlyOwner {
         
        require(sentenced != _sovereign, "Government: sovereign cannot loose citizenship");
        require(_citizens[sentenced].isAlive == true, "Government: impossible punishment since not an alive citizen");
        _cancelCitizen(sentenced);
    }

    
    function changeHealthStatus(address concerned, HealthStatus option) public onlyHospitals {
        require(_citizens[concerned].isAlive == true, "Government: can not change health since not an alive citizen");
        if (option == HealthStatus.Died) {
            _cancelCitizen(concerned);
        } else if (option == HealthStatus.Healthy) {
            _citizens[concerned].isSick = false;
            UpdatedHealth(concerned, false, _citizens[concerned].currentTokens, _citizens[concerned].healthTokens);
        } else if (option == HealthStatus.Sick) {
            _citizens[concerned].isSick = true;
            _citizens[concerned].currentTokens = _citizens[concerned].currentTokens.add(
                _citizens[concerned].healthTokens
            );
            _citizens[concerned].healthTokens = 0;
            UpdatedHealth(concerned, true, _citizens[concerned].currentTokens, _citizens[concerned].healthTokens);
        } else revert("Invalid health status choice");
    }

 
    function changeEmploymentStatus(address concerned) public onlyCompanies {
        require(
            _citizens[concerned].isAlive == true,
            "Government: can not change employment since not an alive citizen"
        );
        if (_citizens[concerned].isWorking == true) {
          
            require(_citizens[concerned].employer == msg.sender, "Government: not working for this company");
            _citizens[concerned].isWorking = false;
            _citizens[concerned].employer = address(0);
            _citizens[concerned].currentTokens = _citizens[concerned].currentTokens.add(
                _citizens[concerned].unemploymentTokens
            );
            _citizens[concerned].unemploymentTokens = 0;
            UpdatedEmployment(
                concerned,
                address(0),
                false,
                _citizens[concerned].currentTokens,
                _citizens[concerned].unemploymentTokens
            );
        } else {
            _citizens[concerned].employer = msg.sender;
            _citizens[concerned].isWorking = true;
            UpdatedEmployment(
                concerned,
                msg.sender,
                true,
                _citizens[concerned].currentTokens,
                _citizens[concerned].unemploymentTokens
            );
        }
    }

   
    function becomeCitizen(uint256 age) public {
      
        require(_citizens[msg.sender].retirementDate == 0, "Government: citizens can not ask again for citizenship");
        uint256 retirementDate =
            RETIREMENT_AGE >= age ? block.timestamp.add((RETIREMENT_AGE.sub(age)).mul(52 weeks)) : block.timestamp;
        _citizens[msg.sender] = Citizen(true, address(0), false, false, retirementDate, AWARD_CITIZENSHIP, 0, 0, 0);
        _token.operatorSend(_sovereign, msg.sender, AWARD_CITIZENSHIP, "", "");
        CreatedCitizen(msg.sender, true, address(0), false, false, retirementDate, AWARD_CITIZENSHIP, 0, 0, 0);
    }

    

    
    function registerHospital(address hospitalAddress) public onlyOwner {
        require(_hospitals[hospitalAddress] == false, "Government: hospital is already registered");
        _hospitals[hospitalAddress] = true;
        SetHospital(hospitalAddress, true);
    }

    
    function unregisterHospital(address hospitalAddress) public onlyOwner {
        require(_hospitals[hospitalAddress] == true, "Government: hospital is already unregistered");
        _hospitals[hospitalAddress] = false;
        SetHospital(hospitalAddress, false);
    }

    
    function registerCompany(address companyAddress) public onlyOwner {
        require(_companies[companyAddress] == false, "Government: company is already registered");
        _companies[companyAddress] = true;
        SetCompany(companyAddress, true);
    }

    
    function unregisterCompany(address companyAddress) public onlyOwner {
        require(_companies[companyAddress] == true, "Government: company is already unregistered");
        _companies[companyAddress] = false;
        SetCompany(companyAddress, false);
    }

    
    function buyTokens(uint256 nbTokens) public payable onlyCompanies returns (bool) {
         
        require(msg.value > 0, "Government: minimum 1 wei");
       
        require(nbTokens >= (DENOMINATION / _price), "Government: minimum 100 tokens");
        
        require(
            (nbTokens * _price) / DENOMINATION <= msg.value,
            "Government: not enough Ether to purchase this number of tokens"
        );
        uint256 _realPrice = (nbTokens * _price) / DENOMINATION;
        uint256 _remaining = msg.value - _realPrice;
        _sovereign.transfer(_realPrice);
        _token.operatorSend(_sovereign, msg.sender, nbTokens, "", "");
        if (_remaining > 0) {
            msg.sender.transfer(_remaining);
        }
        return true;
    }

 

    function paySalary(address employee, uint256 amount) public onlyCompanies {
         
        require(_citizens[employee].employer == msg.sender, "Government: not an employee of this company");
        
        require(_token.balanceOf(msg.sender) >= amount, "Government: company balance is less than the amount");
        uint256 _partSalary = amount.div(10);
        _citizens[employee].healthTokens = _citizens[employee].healthTokens.add(_partSalary);
        _citizens[employee].unemploymentTokens = _citizens[employee].unemploymentTokens.add(_partSalary);
        _citizens[employee].retirementTokens = _citizens[employee].retirementTokens.add(_partSalary);
        _citizens[employee].currentTokens = _citizens[employee].currentTokens.add(amount.sub(_partSalary.mul(3)));
        _token.operatorSend(msg.sender, employee, amount, "", "");
        Paid(
            employee,
            amount,
            msg.sender,
            _citizens[employee].currentTokens,
            _citizens[employee].healthTokens,
            _citizens[employee].unemploymentTokens,
            _citizens[employee].retirementTokens
        );
    }
}