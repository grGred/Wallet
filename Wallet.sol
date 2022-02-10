// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.0.0/contracts/token/ERC20/IERC20.sol";

contract Wallet {
    
    address payable public owner;
    // Allowance for sending Eth
    mapping(address => mapping(address => uint256)) public allowanceEth;
    // Allowance for sending Tokens
    mapping(address => mapping(address => mapping(IERC20 => uint))) public allowanceToken;
    // Mapping of all balances
    mapping(address => uint) private balanceOf;
    // Start comission is 0.1 %
    uint public storedComission = 1;
    // Constant address that will recieve comission
    address constant internal COMISSION_RECIVER_ADDRESS = 0x0A098Eda01Ce92ff4A4CCb7A4fFFb5A43EBC70DC; 
    uint internal comissionAmount;
    uint internal recipientRecives;

    // Block with events
    // Keep track of deposited funds
    event Deposit(address from, uint amount);
    // Keep track of withdrawed funds
    event WithdrawFunds(address to, uint amount);
    // Keep track of ethereum transfers
    event TransferFunds(address from, address to, uint amount);
    event TransferFundsWithAllowance(address from, address to, uint amount);
    // Keep track of Token transfers
    event TransferERC20(IERC20 token, address from, address to,  uint amount);
    event TransferERC20WithAllowance(IERC20 token, address sender, address from, address to, uint amount);
    // Keep track of allowances approved
    event ApprovalEth(address owner, address spender, uint256 value);
    event ApprovalToken(address owner, address spender, IERC20 token, uint256 value);
    
    constructor() public payable {
        owner = payable(msg.sender);
    }

    // modifier that checks, if a msg.sender is an owner
    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /// @dev external function that accept all the values to a smartcontract
    //  event Deposit
    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
    
    /// @dev public function that can be called only by owner
    /// @param _fee new fee number, changes comission to 0.x%
    //  You can't set comission more than 5%
    function setComission(uint _fee) public onlyOwner {
        require(_fee <= 50, "You can't set comission more than 5%");
        storedComission = _fee;
    }

    /// @dev internal function that takes our comission and count amount to send, amount of comission
    /// @param _amount amount value of ETH to send without comission
    //  rerutns amount to send, amount of comission
    function getComission(uint _amount) internal returns (uint, uint) {
        uint amountOfComission = _amount * storedComission / 1000;
        uint sendedAmount = _amount - _amount * storedComission / 1000;
        return (sendedAmount, amountOfComission);
    }

    /// @dev internal transfer function with required safety checks
    /// @param _from, where funds coming the sender
    /// @param _to receiver of Eth
    /// @param _amount amount value of ETH to send
    function _transfer(address _from, address payable _to, uint256 _amount) internal {
        // Ensure sending is to valid address, not 0x0 address
        require(_to != address(0));
        balanceOf[_from] -= _amount;
        _to.transfer(_amount);
    }

    /// @dev withdraw Eth only by token holder
    /// @param _amount amount value of Eth to send
    //  recipientRecives amount of Eth recipient recieves except comission
    //  comissionAmount amount of comission COMISSION_RECIVER_ADDRESS recieves
    //  Transfer Funds to recipient and COMISSION_RECIVER_ADDRESS 
    //  WithdrawFunds event
    //  transfer Eth back to wallet
    function withdrawEthSupportingFee(uint _amount) external payable {
        require(balanceOf[msg.sender] >= _amount, "Insufficient amount");
        (recipientRecives, comissionAmount) = getComission(_amount);
        address payable _withdrawAddress = payable(msg.sender);
        _withdrawAddress.transfer(recipientRecives);
        _transfer(msg.sender, payable(COMISSION_RECIVER_ADDRESS), comissionAmount);
        emit WithdrawFunds(_withdrawAddress, recipientRecives);
    }
    
    /// @dev transfer by approved person from original address of an amount within approved limit 
    /// @param _from address sending Eth
    /// @param _recipient receiver of Eth
    /// @param _amount amount value of Eth to send
    //  recipientRecives amount of Eth recipient recieves except comission
    //  comissionAmount amount of comission COMISSION_RECIVER_ADDRESS recieves
    //  Transfer Funds to recipient and COMISSION_RECIVER_ADDRESS 
    //  TransferFundsWithAllowance event
    //  Allow _spender to spend up to _amount on your behalf
    function fromTransferEthSupportingFee(
        address _from, 
        address payable _recipient, 
        uint256 _amount
        ) external payable {
        require(balanceOf[_from] >= _amount, "Sender insufficient funds");
        require(allowanceEth[_from][msg.sender] >= _amount, "Not enough approved tokens");
        (recipientRecives, comissionAmount) = getComission(_amount);
        allowanceEth[_from][msg.sender] -= (_amount);
        _transfer(_from, _recipient, recipientRecives);
        _transfer(_from, payable(COMISSION_RECIVER_ADDRESS), comissionAmount);
        emit TransferFundsWithAllowance(_from, _recipient, recipientRecives);
    }
    
    /// @dev Funds owner transfer Eth to _recipient
    /// @param _recipient receiver of Eth
    /// @param _amount amount value of Eth to send
    //  recipientRecives amount of Eth recipient recieves except comission
    //  comissionAmount amount of comission COMISSION_RECIVER_ADDRESS recieves
    //  Transfer Funds to recipient and COMISSION_RECIVER_ADDRESS
    //  TransferFunds event
    //  Allow funds owner spend up his Eth
    function transferEthSupportingFee(
        address payable _recipient, 
        uint _amount
        ) external payable {
        require(balanceOf[msg.sender] >= _amount, "Insufficient funds");
        (recipientRecives, comissionAmount) = getComission(_amount);
        _transfer(msg.sender, _recipient, recipientRecives);
        _transfer(msg.sender, payable(COMISSION_RECIVER_ADDRESS), comissionAmount);
        emit TransferFunds(msg.sender, _recipient, recipientRecives);
    }

    /// @notice Checks balance of Eth in contract
    function walletBalanceEth() public view returns(uint) {
      return (balanceOf[msg.sender]);
    }

    /// @notice Checks balance of Tokens in contract
    function walletBalanceToken(IERC20 _tokenAddr) public view returns(uint) {
      return (_tokenAddr.balanceOf(address(this)));
    }

    /// @dev Approves amount of Eth that spender can use
    /// @param _spender address that can use our Eth
    /// @param _value amount value of Eth to share with address
    // event ApprovalEth
    function approveEth(address _spender, uint _value) external {
        require(_spender != msg.sender, "You are already allowed to move your Ether");
        require(balanceOf[msg.sender] >= _value, "You cannot approve more Eth then you have");
        allowanceEth[msg.sender][_spender] = _value;
        emit ApprovalEth(msg.sender, _spender, _value);
    }

    /// @dev Approves amount of Tokens that spender can use
    /// @param _spender address that can use our Tokens
    /// @param _tokenAddr token address we are ready to share
    /// @param _value amount value of Eth to share with address
    //  event ApprovalToken
    function approveToken(address _spender, IERC20 _tokenAddr, uint _value) external {
        require(_spender != msg.sender, "You are already allowed to move your Tokens");
        require(_tokenAddr.balanceOf(address(this)) >= _value, "You cannot approve more tokens then you have");
        allowanceToken[msg.sender][_spender][_tokenAddr] = _value;
        emit ApprovalToken(msg.sender, _spender, _tokenAddr, _value);
    }

    /// @dev transfer ERC20 tokens to address
    /// @param _tokenAddr token address we are sending
    /// @param _to token recipient 
    /// @param _amount amount of tokens we are sending
    //  event TransferERC20
    function transferERC20(
        IERC20 _tokenAddr, 
        address _to, 
        uint _amount
        ) external { 
        require(_tokenAddr.balanceOf(address(this)) >= _amount, "Insufficient funds");
        (recipientRecives, comissionAmount) = getComission(_amount);
        _tokenAddr.transfer(_to, recipientRecives);
        _tokenAddr.transfer(COMISSION_RECIVER_ADDRESS, comissionAmount);
        emit TransferERC20(_tokenAddr, msg.sender, _to, recipientRecives);
    }

    /// @dev transfer ERC20 tokens to address
    /// @param _tokenAddr token address we are sending
    /// @param _from address sending Tokens
    /// @param _to token recipient 
    /// @param _amount amount of tokens we are sending
    //  event TransferERC20WithAllowance
    function fromTransferERC20(
        IERC20 _tokenAddr, 
        address _from, 
        address _to, 
        uint _amount
        ) external { 
        require(_tokenAddr.balanceOf(address(this)) >= _amount, "Insufficient funds");
        require(allowanceToken[_from][msg.sender][_tokenAddr] >= _amount, "Not enough approved tokens");
        allowanceToken[_from][msg.sender][_tokenAddr] -= _amount;
        (recipientRecives, comissionAmount) = getComission(_amount);
        _tokenAddr.transfer(_to, recipientRecives);
        _tokenAddr.transfer(COMISSION_RECIVER_ADDRESS, comissionAmount);
        emit TransferERC20WithAllowance(_tokenAddr, msg.sender, _from, _to, recipientRecives);
    }
}
