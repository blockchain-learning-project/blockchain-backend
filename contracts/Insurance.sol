// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

interface DisasterInterface  {
    function setSeverity(string memory district, uint newSeverity) external;
    function getSeverityData(string memory district, uint day) external view returns (uint);
    function getDistricts() external pure returns (string memory);
    function getAccumulatedSeverity(string memory district) external view returns (uint);
    function getTotalAccumulatedSeverity() external view returns (uint256);
}

contract Insurance
{
    struct farmer
    {
        address farmer_address;
        string district;

        uint256 total_paid_premium;
        uint256[] paid_premium;
        uint256[] paid_timestamp;

        bool locked;
    }
    
    bool public contractLock;
    uint256 public startDay;
    uint256 public endDay;

    farmer[] public list_farmer;
    mapping(address => uint256) public list_farmer_index;
    mapping(address => bool) public list_farmer_valid;

    mapping(uint256 => uint256) public day_aggregate;

    // Calculating sum( x(i) * y(i) ),
    // tried to reduce time complexity form O(n * m) to O(n),
    // where n => number of days from start to end & m => numbers of farmers.
    uint256 public totalDayFactorAggregate;

    uint256 public totalSeverityFactorAggregate;

    DisasterInterface DisasterInterfaceObject;
    modifier unlocked
    {
        require(contractLock == false, "Contract has been locked");
        _;
    }

    modifier onlyFarmer
    {
        require(list_farmer_valid[msg.sender] == true, "You are not registered");
        _;
    }

    constructor()
    {
        contractLock = false;
        startDay = getDay();
        DisasterInterfaceObject = DisasterInterface(0x9D7f74d0C41E726EC95884E0e97Fa6129e3b5E99);
    }

    function getFarmer() public view returns(farmer memory)
    {
        uint256 farmer_index = list_farmer_index[msg.sender];

        return list_farmer[farmer_index];
    }


    // !!! remove this before submission
    uint256 public c_day = 0;
    function setDay(uint256 day) public
    {
        c_day = day;
    }
    function getDay() private view returns(uint256)
    {
        return c_day;
    } 

/* 
    function getDay() private view returns(uint256)
    {
        return (block.timestamp) / 5 minutes;
    } */

    function registerFarmer(string memory district_) public unlocked
    {
        require(list_farmer_valid[msg.sender] == false, "You are already registered");

        farmer memory tmp;
        tmp.farmer_address = msg.sender;
        tmp.district = district_;
        tmp.locked = false;
        list_farmer.push(tmp);
        
        list_farmer_index[msg.sender] = list_farmer.length -1;
        list_farmer_valid[msg.sender] = true;
    }

    function payPremium() public payable unlocked
    {
        require(msg.value != 0, "Premium cannot be zero");
        require(list_farmer_valid[msg.sender] == true, "You are not registered");

        uint current_day = getDay();
        uint256 farmer_index = list_farmer_index[msg.sender];

        farmer storage t_farmer = list_farmer[farmer_index];
        current_day = current_day - startDay;
        t_farmer.paid_premium.push(msg.value);
        t_farmer.paid_timestamp.push(current_day);
        t_farmer.total_paid_premium += msg.value;

        day_aggregate[current_day] += msg.value;
    }
    
    function calculateAggregateDayFactor() private view returns (uint256)
    {
        uint256 day_aggregator_length = endDay - startDay;
        uint256 aggregate_day_factor = 0;
        uint256 j = 1;
        for(uint256 i = day_aggregator_length; i>= 0 ;i--)
        {
            aggregate_day_factor += day_aggregate[i] * j;
            j++;

            if(i == 0)
                break;
        }
        return aggregate_day_factor;
    }

    //flawed => 10 0 50 0 0 will be calculated as 10 50
    function calculateDayFactor(farmer memory t_farmer) private view returns (uint256)
    {
        uint256 t_day_factor = 0;
        uint256 j = 1;
        for(uint256 i = t_farmer.paid_premium.length -1; i >= 0; i--)
        {
            t_day_factor += t_farmer.paid_premium[i] * (endDay - t_farmer.paid_timestamp[i] +1);
            j++;
            
            if(i == 0)
                break;
        }

        return t_day_factor;
    }

    event cnumber
    (
        uint endDay,
        uint totalDayFactorAggregate,
        uint totalSeverityFactorAggregate,
        uint day_factor,
        uint severity_factor,
        uint p1,
        uint p2,
        uint numerator,
        uint denominator
    );

    function claimInsurance() public payable
    {
        uint256 today = getDay();
        farmer memory t_farmer = list_farmer[list_farmer_index[msg.sender]];

        if(contractLock != true)
        {
            contractLock = true;
            endDay = today;
            
            totalDayFactorAggregate = calculateAggregateDayFactor();
            totalSeverityFactorAggregate = DisasterInterfaceObject.getTotalAccumulatedSeverity();
        }

        uint256 day_factor = calculateDayFactor(t_farmer);
        uint256 severity_factor = DisasterInterfaceObject.getAccumulatedSeverity(t_farmer.district);

        uint256 p1 = totalSeverityFactorAggregate * day_factor;
        uint256 p2 = totalDayFactorAggregate * severity_factor;
        uint256 numerator = (p1 + p2) * t_farmer.total_paid_premium;
        uint256 denominator = (2 * totalDayFactorAggregate * totalSeverityFactorAggregate);

        emit cnumber(endDay, totalDayFactorAggregate, totalSeverityFactorAggregate, day_factor, severity_factor, p1, p2, numerator, denominator);

        uint256 total_insurance_amount = numerator / denominator;

        payable(t_farmer.farmer_address).transfer(total_insurance_amount);
    }
}