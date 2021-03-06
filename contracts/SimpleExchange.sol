pragma solidity ^0.4.19;

import './Token.sol';

contract SimpleExchange {

    // Contract semantic version
    string public constant version = '0.1.0';

    address public owner_address;
    address public wallet_address;
    Token public token;
    uint256 public token_multiplier;

    // Limit the amount of WEI that an address can pay for the token
    uint256 public wei_max_per_address;

    // Fixed token price in WEI
    uint256 public wei_per_token;

    // Keep track of how much WEI each address has spent
    mapping (address => uint256) public wei_per_address;

    /*
     * Modifiers
     */

    modifier isOwner() {
        require(msg.sender == owner_address);
        _;
    }

    modifier isWallet() {
        require(msg.sender == wallet_address);
        _;
    }

    /*
     *  Events
     */

    event Setup(uint256 _wei_max_per_address, uint256 _wei_per_token);
    event Fund(uint256 _token_fractions);
    event Buy(address indexed _buyer, uint256 _value, uint256 _token_fractions);
    event WithdrawTokens(uint256 _token_fractions);

    function SimpleExchange(address _token_address, address _wallet_address, uint256 _wei_max_per_address, uint256 _wei_per_token) public {
        require(_token_address != 0x0);
        require(_wallet_address != 0x0);
        require(addressHasCode(_token_address));

        token = Token(_token_address);
        // Check if the contract is indeed a token contract
        require(token.totalSupply() > 0);

        token_multiplier = 10 ** uint256(token.decimals());
        wallet_address = _wallet_address;
        owner_address = msg.sender;
        setup(_wei_max_per_address, _wei_per_token);
    }

    function () external payable {
        buy(msg.sender);
    }

    function setup(uint256 _wei_max_per_address, uint256 _wei_per_token) public isOwner {
        require(_wei_max_per_address > 0);
        require(_wei_per_token > 0);

        wei_max_per_address = _wei_max_per_address;
        wei_per_token = _wei_per_token;
        Setup(wei_max_per_address, wei_per_token);
    }

    function buy(address _buyer) public payable {
        require(msg.value > 0);
        require(wei_per_address[_buyer] + msg.value <= wei_max_per_address);
        require(wei_per_address[_buyer] + msg.value >= msg.value);

        wei_per_address[_buyer] += msg.value;
        uint256 token_fractions = msg.value * token_multiplier / wei_per_token;

        wallet_address.transfer(msg.value);
        require(token.transfer(_buyer, token_fractions));

        Buy(address indexed _buyer, msg.value, token_fractions);
    }

    function tokenFallback(address _sender_address, uint256 _deposit, bytes _data) external {
        require(_deposit > 0);

        // Make sure we trust the token
        require(msg.sender == address(token));

        // Make sure only the trusted wallet sends tokens
        require(_sender_address == wallet_address);

        Fund(uint256 _deposit);
    }

    function withdrawTokens() external isWallet {
        uint256 contract_balance = token.balanceOf(address(this));
        require(token.transfer(wallet_address, contract_balance));
        WithdrawTokens(contract_balance);
    }

    /// @dev Check if a contract exists.
    /// @param _contract The address of the contract to check for.
    /// @return True if a contract exists, false otherwise
    function addressHasCode(address _contract) internal constant returns (bool) {
        uint size;
        assembly {
            size := extcodesize(_contract)
        }
        return size > 0;
    }
}
