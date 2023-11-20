// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "hardhat/console.sol";


contract Token is Context, ERC20Burnable, Ownable {
    using Address for address;
    string private tokenName;
    string private tokenSymbol;
    uint8 private constant tokenDecimals = 9;
    
    uint256 private _tTotal = 100000000 * 10 ** tokenDecimals;
    uint256 private tokenTotalSupply = _tTotal;

    address public teamAddress;
    address public liquidityPoolAddress;
    address public liquidityPair;

    uint private burnFee = 20; //0.2% divisor 100
    uint private liquidityFee = 40; //0.4% divisor 100
    uint private teamFee = 20; //0.2% divisor 100
    uint256 public maxTxAmount = 500000 * 10**decimals();

    mapping(address => uint256) private _balances;
    mapping(address => bool) public feeExcludedAddress;

    
    constructor(string memory _tokenName , string memory _tokenSymbol) ERC20(_tokenName, _tokenSymbol) Ownable() {
        tokenName = _tokenName;
        tokenSymbol = _tokenSymbol;
        feeExcludedAddress[_msgSender()] = true;
        _mint(_msgSender(), tokenTotalSupply);
    }

    function name() public view override returns (string memory) {
        return tokenName;
    }

    function symbol() public view override returns (string memory) {
        return tokenSymbol;
    }

    function totalSupply() public view override returns (uint256) {
        return tokenTotalSupply;
    }

    function decimals() public view virtual override returns (uint8) {
        return tokenDecimals;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function calculateBurnFee(uint256 amount) internal view returns (uint256) {
        return (amount * burnFee) / (10**4);
    }

    function calculateLiquidityFee(uint256 amount) internal view returns (uint256) {
        return (amount * liquidityFee) / (10**4);
    }

    function calculateTeamFee(uint256 amount) internal view returns (uint256) {
        return (amount * teamFee) / (10**4);
    }

    function _mint(address account, uint256 amount) internal virtual override{
        require(account != address(0), "ERC20: mint to the zero address");

        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual override{
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            tokenTotalSupply -= amount;
        }
        emit Transfer(account, address(0), amount);
    }
    
    function burn(uint256 amount) public override {
         require(
            _msgSender() != address(0),
            "ERC20: burn from the dead address"
        );
        _burn(_msgSender(), amount);
    }

    function addExcludedAddress(address excludedAddress) external onlyOwner{
        require(
            feeExcludedAddress[excludedAddress] == false,
            "Account is already included in Fee."
        );
        feeExcludedAddress[excludedAddress] = false;
    }
    
    function removeExcludedAddress(address excludedAddress) external onlyOwner{
        require(
            feeExcludedAddress[excludedAddress] == true,
            "Account is already excluded from Fee."
        );
        feeExcludedAddress[excludedAddress] = true;
    }

    function setLiquidityPairAddress(address liquidityPairAddress) external onlyOwner{
        liquidityPair = liquidityPairAddress;
    }
    
    function changeLPAddress(address lpAddress) external onlyOwner{
        liquidityPoolAddress = lpAddress;
    }

    function changeTeamAddress(address _teamAddress) external onlyOwner{
        teamAddress = _teamAddress;  
    }

    function setBurnFee(uint256 _burnFee) external onlyOwner{
        burnFee = _burnFee;
    }
    
    function setLiquidityFee(uint _liquidityFee) external onlyOwner{
        liquidityFee = _liquidityFee;
    }
    
    function setTeamFee(uint _teamFee) external onlyOwner{
        teamFee = _teamFee;
    }

    function setMaxTxAmount(uint256 _maxTxAmount) external onlyOwner{
        maxTxAmount = _maxTxAmount;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        if(sender != owner() && recipient != owner())
            require(amount <= maxTxAmount, "Transfer amount exceeds the maxTxAmount.");

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[sender] = senderBalance - amount;
        uint256 tokenToTransfer = (((amount - calculateLiquidityFee(amount)) - calculateBurnFee(amount)) - calculateTeamFee(amount));
        console.log('zaid', tokenToTransfer);

        _balances[recipient] += tokenToTransfer;
        _balances[teamAddress] += calculateTeamFee(amount); 
        _balances[address(0)] += calculateBurnFee(amount);
        _balances[liquidityPair] += calculateLiquidityFee(amount);
        
        emit Transfer(sender, recipient, tokenToTransfer);
    }

    function _transferExcluded(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        if(sender != owner() && recipient != owner())
            require(amount <= maxTxAmount, "Transfer amount exceeds the maxTxAmount.");

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] = _balances[recipient] + amount;
        
        emit Transfer(sender, recipient, amount);
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        // if(feeExcludedAddress[recipient] || feeExcludedAddress[_msgSender()]){
        if(feeExcludedAddress[recipient]){
            _transferExcluded(_msgSender(), recipient, amount);
        }else{
            _transfer(_msgSender(), recipient, amount);    
        }
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(sender, spender, amount);
        //  if(feeExcludedAddress[recipient] || feeExcludedAddress[sender]){
        if(feeExcludedAddress[recipient]){    
            _transferExcluded(sender, recipient, amount);
        }else{
            _transfer(sender, recipient, amount);
        }
        return true;
    }

    function batchTransfer(address[] memory receivers, uint256[] memory amounts) external returns(bool){
        require(receivers.length != 0, 'Cannot Proccess Null Transaction');
        require(receivers.length == amounts.length, 'Address and Amount array length must be same');
        for (uint256 i = 0; i < receivers.length; i++)
            transfer(receivers[i], amounts[i]);
        return true;    
    }
}