//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./Token.sol";

contract ICO {

    uint256 public tokensSold;
    uint256 public tokenPrice;
    uint256 public maxBuyLimit;
    bool public icoActive;

    mapping(address => uint256) walletPurchased;

    Token public token;

    modifier onlyOwner{
        require(msg.sender == token.owner(), "invalid owner address");
        _;
    }

    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);

    constructor(address _token){
        token = Token(_token);
        require(msg.sender == token.owner(), "Deployer wallet must be Token Owner");
        tokenPrice = 0.001 ether;
        maxBuyLimit = 50000;
        tokensSold = 0;
        icoActive = true;
    }

    function updateTokenPrice(uint256 _tokenPrice) public onlyOwner{
        tokenPrice = _tokenPrice;
    }

    function updateMaxBuyLimit(uint256 _maxLimit) public onlyOwner{
        maxBuyLimit = _maxLimit;
    }

    function buyTokens() external payable {
        require(icoActive, "ICO Ended");
        uint256 etherAmount = msg.value;
        uint256 tokensToBuy = (etherAmount / tokenPrice);
        require(walletPurchased[msg.sender] + tokensToBuy < maxBuyLimit,"You are exceeding max value.");
        
        unchecked{
            walletPurchased[msg.sender] += tokensToBuy;
            tokensSold += tokensToBuy;
        }

        tokensToBuy = tokensToBuy * (10 ** token.decimals());
        if(token.balanceOf(token.owner()) <= tokensToBuy)
            revert("Insufficient Total Supply");

        (bool success,) = token.owner().call{value: msg.value}("");
        if(!success) {
            revert("Payment Sending Failed");
        }else{
            token.transferFrom(token.owner(), msg.sender, tokensToBuy);
            emit TokensPurchased(msg.sender, tokensToBuy, etherAmount);
        }
    }

    function endICO() external onlyOwner {
        require(icoActive, "ICO already ended");
        icoActive = false;
    }

}