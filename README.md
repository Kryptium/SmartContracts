# Kryptium – Smart Contracts
[Kryptium](https://kryptium.io) is a user-friendly, decentralised, peer-to-peer betting platform based on Ethereum blockchain technology. It is designed to scale as a global, community-powered betting ecosystem where anyone can act as a player, house or data service provider.

To use Kryptium as a player, you need to download and install the betting app which is currently available for [Windows, macOS and Linux](https://kryptium.io/#try_it).

Kryptium “back-end” functionality is implemented in the form of smart contracts which can be deployed on Ethereum or other Solidity-compatible blockchain networks (Ethereum Classic, Expanse, PIRL, Callisto, Ellaism, POA and Musicoin). 
- **Oracle smart contract.** For publishing events and their outcomes on the blockchain. It can support events from various sectors, including sports, politics, e-sports, stock markets etc. Oracle smart contracts are independent from the rest of the platform, since they can be deployed by anybody and provide their event data to any other smart contract or app. 
- **House smart contract.** It registers bets, receives stakes and transfers funds to winners’ accounts based on the outcomes of the corresponding events. The “trusted source of truth” for all event data is an oracle smart contract. House smart contracts can be fully autonomous or managed and might charge a commission for their services. The “managed” version allows its owners to cancel bets which they might consider as “unfair”.
- **Tracker smart contract.** It functions as a “registry” of Kryptium house smart contracts and keeps track of users’ upvotes/downvotes. Tracker smart contracts can be fully autonomous or managed. The “managed” version allows “controlled” registration of houses by the owner of the smart contract. The deployment of this component is optional.

## Deployment methods

### App-based / automated (coming soon)
Version 2.1 of the Kryptium betting app will support transparent deployment and management of Kryptium betting houses (house smart contracts) and data services (oracle smart contracts). This will allow anybody to use the platform to its fullest potential, even if they don’t have deep technical knowledge of blockchain internals.

### Manual
However, until Kryptium app v.2.1 is out, the only way to deploy Kryptium smart contracts is by using Solidity development tools. The next sections provide instructions for the manual deployment and use of oracle and house smart contracts which are essential for setting up your own Kryptium-powered betting house. The instructions assume that the reader has basic technical knowledge of the Ethereum blockchain network and basic familiarity with the necessary tools.

## Oracle deployment
1. Open a browser which has the Metamask plugin installed and launch Metamask. Unlock your account and select your desired destination network (e.g. “Ropsten Testnet Network”). The unlocked account should have some Ether in the selected blockchain network.

2. Navigate to  https://remix.ethereum.org/#optimize=true&version=soljson-v0.5.8+commit.23d335f2.js (For Ellaism https://remix.ethereum.org/#optimize=true&version=soljson-v0.5.2+commit.1df8f40c.js)

3. Click the icon “Add local file to the browser storage explorer”

    ![add local file](/images/add_local_file.png)

4. In the “File name” textbox, enter the URL https://raw.githubusercontent.com/Kryptium/SmartContracts/master/oracle.sol 
 
    ![file name](/images/file_name.png)

5. Click “Start to compile”
 
    ![start to compile](/images/start_to_compile.png)

6. Switch to “Run” tab and select “Oracle” from the dropdown
 
    ![select oracle](/images/select_oracle.png)

7. Select “Injected Web3” in the “Environment” dropdown. Enter 4700000 in the “Gas limit” textbox

    ![injected web3](/images/injected_web3.png)
 
8. Expand the “Deploy” section and fill in the required values:

    ```
    oracleName: <Your Oracle name>
    oracleCreatorName: <Oracle creator name (You)>
    version: <Enter the value 105>
    ```

    ![deploy section](/images/deploy_section.png) 

    Click “transact”. A Metamask dialog will open asking to confirm the transaction. Press “Confirm” and wait for the transaction to be mined.

9. Monitor the transaction’s status by clicking the link under the “creation of Oracle pending…” at the logs area of Remix.

    ![creation of oracle pending](/images/creation_of_oracle_pending.png)

10. Once the transaction is mined, look at the “Deployed Contracts” area; you should see something like this:

    ![deployed contracts](/images/deployed_contracts.png)

11. Copy the address and store it somewhere, as it will be needed in the next steps

## Publish a Subcategory on your Oracle smart contract
1. Expand the “setSubcategory” section on the “Deployed Contracts” area and fill in the required values:

    ```
    Id: <A unique Id for your Subcategory. Use zero for an autoincrement automatic value>
    categoryId: <One of the currently supported values below: 
      "1" for Football (Soccer)
      "2" for Basketball
      "3" for Baseball
      "4" for American Football
      "5" for Boxing
      "6" for Horse Racing
      "7" for Cycling
      "8" for Tennis
      "9" for E-sports
      "10" for Golf
      "11" for Rugby
      "12" for Motor Racing
      "13" for Cricket
      "14" for UFC/MMA
      "15" for Handball
      "16" for Snooker
      "17" for Darts
      "18" for Winter Sports
      "19" for Ice Hockey
      "20" for Volleyball
      "101" for Cryptocurrencies
      "102" for Stock Markets
      "201" for TV Series
      "202" for Cinema
      "301" for Elections
      "1001" for Miscellaneous>
    Name: <Your Subcategory name (e.g. “NBA”)>
    Country: <Empty string for multinational subcategories or an ISO ALPHA-2 country code (e.g. “US” for United States)>
    Hidden: <Enter "false">
    ```

    ![set subcategory](/images/set_subcategory.png)

    Click “transact”. A Metamask dialog will open asking to confirm the transaction. Press “Confirm” and wait for the transaction to be mined.

2. Monitor the transaction’s status by clicking the link under the “transact to Oracle.setSubcategory pending ...” at the logs area of Remix

3. Once your transaction is mined, check your newly created Subcategory by expanding the “subcategories” section. Enter the subcategory Id to get the Subcategory info from the blockchain

    ![subcategory info](/images/subcategory_info.png)

## Publish an Event on your Oracle smart contract
1. Expand the "addUpcomingEvent" section and fill in the required values:

    ```
    Id: <A unique Id for your Event. Use zero for an autoincrement automatic value.>
    title: <Event title (e.g. “Denver Nuggets - Portland Trail Blazers”)>
    startDateTime: <The event start time in epoch format (e.g. 1639965600)>
    endDateTime: <The event end time in epoch format (e.g. 1639976400)>
    subcategoryId: <The Subcategory Id of the previously created subcategory>
    categoryId: <"2" for Basketball, see previous list of category ids>
    outputTitle: <An output/outcome label abi encoded bytes32,
      To convert a string to bytes32 open the development tools in your browser, 
      go to the console and type web3.fromAscii("{string to be converted}"). e.g. “Winner” should be "0x57696e6e6572">
    eventOutputType: <Enter "0">
    _possibleResults: <abi encoded array of bytes32. 
      To convert a string to bytes32 open the development tools in your browser, 
      go to the console and type web3.fromAscii("{string to be converted}"). 
      For the NBA game “Denver Nuggets - Portland Trail Blazers” the correct input 
      of _possibleResults is: 
      ["0x44656e766572204e756767657473","0x506f72746c616e6420547261696c20426c617a657273"]>
    decimals: 0,
    cancelled: false
    ```
    
    ![add upcoming event](/images/add_upcoming_event.png)
 
    Then click “transact”. A Metamask dialog will open asking to confirm the transaction. Press “Confirm” and wait for the transaction to be mined.

2. Monitor the transaction’s status by clicking the link under the “transact to Oracle.addUpcomingEvent pending ...” at the logs area of Remix

3. Once the transaction is mined, check your new Event by expanding the “events” section. Enter the unique event id to get the Event info from the blockchain
 
    ![get event info](/images/get_event_info.png)

## Set the result of an Event
1. Expand the "setEventOutcome" section and fill in the values:

    ```
    eventId: <The unique Event Id (e.g. 1 for the above deployed Event)>
    outputId: 0
    announcement: <The final score of the Event (e.g. “102-118”) abi encoded bytes32,
      To convert a string to bytes32 open the development tools in your browser, 
      go to the console and type web3.fromAscii("{string to be converted}"). e.g. 102-118 should be "0x3130322d313138">
    setEventAnnouncement: true
    _eventOutcome: <The index of the result, from the array of event’s possible results, 
      that won the Event. If the score of the "Denver Nuggets - Portland Trail Blazers" 
      was 102-118 then Portland Trail Blazers won the match so the right index is 1>
    ```
    
    ![set_event_outcome](/images/set_event_outcome.png)
 
    Click transact and wait the transaction to be mined.

## Deploy a House that uses your Oracle as a source of Events
1. Click the “Add local file to the browser storage explorer”

    ![add local file](/images/add_local_file.png)

2. In the “File name” textbox enter the URL https://raw.githubusercontent.com/Kryptium/SmartContracts/master/house.sol 
 
    ![file name house](/images/file_name_house.png)

3. Click “Start to compile”

    ![start to compile](/images/start_to_compile.png)

4. Switch to the “Run” tab and select “House” from the dropdown
 
    ![house dropdown](/images/house_dropdown.png)

5. Expand the Deploy section and fill in the values:

    ```
    managed: true
    houseName: <Your House name>
    houseCreatorName : <House creator name(You)>
    oracleAddress: <An Oracle address. Use the address of your previously deployed Oracle smart contract>
    housePercentage: <‰ of your House commission>
    oraclePercentage: <‰ of fees to be assigned to the Oracle smart contract owner>
    closeBeforeStartTime: <Closing time for bets on upcoming events, in minutes before the start of the event>
    closeEventOutcomeTime: <Freeze time for finalisation of event outcomes, in minutes after the end of the event>
    Version: <Enter "105">
    ```

    ![deploy house](/images/deploy_house.png)
 
    Press transact and wait for the transaction to be mined.

6. Once the transaction mined look at the “Deployed Contracts” area, you will see something like:

    ![deployed contracts house](/images/deployed_contracts_house.png)

## Enable betting on your newly deployed House
1. Expand the "startNewBets" section and click “transact”.
