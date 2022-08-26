// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract insurance
{
    struct farmer
    {
        address farmer_address;
        string district;

        uint256[] paid_premium;
        uint256[] paid_timestamp;
    }
    
    bool public contractLock;

    farmer[] public list_farmer;
    mapping(address => uint256) public list_farmer_index;
    mapping(address => bool) public list_farmer_valid;

    modifier unlocked
    {
        require(contractLock == false, "Contract has been locked");
        _;
    }

    constructor()
    {
        contractLock = false;
    }

    function getFarmer() public view returns(farmer memory)
    {
        uint256 farmer_index = list_farmer_index[msg.sender];

        return list_farmer[farmer_index];
    }
    function getDay() private view returns(uint256)
    {
        return (block.timestamp) / 5 minutes;
    }

    function registerFarmer(string memory district_) public unlocked
    {
        require(list_farmer_valid[msg.sender] == false, "You are already registered");

        farmer memory tmp;
        tmp.farmer_address = msg.sender;
        tmp.district = district_;
        list_farmer.push(tmp);
        
        list_farmer_index[msg.sender] = list_farmer.length -1;
        list_farmer_valid[msg.sender] = true;
    }

    function payPremium() public payable unlocked
    {
        require(msg.value != 0, "Premium cannot be zero");
        require(list_farmer_valid[msg.sender] == true, "You are not registered");

        uint day = getDay();
        uint256 farmer_index = list_farmer_index[msg.sender];

        farmer storage f_tmp = list_farmer[farmer_index];
        f_tmp.paid_premium.push(msg.value);
        f_tmp.paid_timestamp.push(day);
    }
}
