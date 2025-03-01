# 🏗 Scaffold-ETH 2

Contractly: https://sepolia.etherscan.io/address/0xf76c12d8f8e18e6c2276b143887b82254f585088
Agreement: https://sepolia.etherscan.io/address/0x8ceb2ad172cdd8b0d932904e657c456382ba0aee

# Contract Interaction Diagrams (Mermaid)

## 1. Basic Contract Flow

```mermaid
graph TD
    User([User]) --> Agreement([Agreement Contract])
    Agreement --> Contractly([Contractly Contract])
    
    User -->|createAgreement| Agreement
    User -->|signAgreement| Agreement
    User -->|stakeAgreement| Agreement
    User -->|fulfillAgreement| Agreement
    User -->|breachAgreement| Agreement
    
    Agreement -->|delegates all calls| Contractly
```

## 2. Function Sequence Diagram

```mermaid
sequenceDiagram
    actor User
    participant Agreement
    participant Contractly
    
    User->>Agreement: createAgreement()
    Agreement->>Contractly: createAgreement()
    Contractly-->>Agreement: return agreementId
    Agreement-->>User: return agreementId
    
    User->>Agreement: signAgreementWithStakeDetails()
    Agreement->>Contractly: getParty()
    Agreement->>Contractly: signAgreement()
    
    User->>Agreement: stakeAgreement()
    Agreement->>Contractly: stakeAgreement()
    Agreement->>Contractly: stakedFunds()
    Note over Agreement,Contractly: If all parties staked
    Agreement->>Contractly: lockAgreement()
```

## 3. Agreement State Flow

```mermaid
stateDiagram-v2
    [*] --> Created: createAgreement
    Created --> Signed: signAgreementWithStakeDetails
    Signed --> Locked: stakeAgreement (all parties)
    Locked --> Fulfilled: fulfillAgreement
    Locked --> Breached: breachAgreement
    Fulfilled --> [*]
    Breached --> [*]
```

## 4. Class Diagram

```mermaid
classDiagram
    class Agreement {
        +createAgreement()
        +signAgreementWithStakeDetails()
        +stakeAgreement()
        +fulfillAgreement()
        +breachAgreement()
        +getAgreementDetails()
        -addParty()
    }
    
    class Contractly {
        +createAgreement()
        +getParty()
        +signAgreement()
        +addParty()
        +stakeAgreement()
        +lockAgreement()
        +fulfillAgreement()
        +breachAgreement()
        +getAgreement()
        +stakedFunds()
    }
    
    Agreement --> Contractly : Uses
```


<h4 align="center">
  <a href="https://docs.scaffoldeth.io">Documentation</a> |
  <a href="https://scaffoldeth.io">Website</a>
</h4>

🧪 An open-source, up-to-date toolkit for building decentralized applications (dapps) on the Ethereum blockchain. It's designed to make it easier for developers to create and deploy smart contracts and build user interfaces that interact with those contracts.

⚙️ Built using NextJS, RainbowKit, Foundry, Wagmi, Viem, and Typescript.

- ✅ **Contract Hot Reload**: Your frontend auto-adapts to your smart contract as you edit it.
- 🪝 **[Custom hooks](https://docs.scaffoldeth.io/hooks/)**: Collection of React hooks wrapper around [wagmi](https://wagmi.sh/) to simplify interactions with smart contracts with typescript autocompletion.
- 🧱 [**Components**](https://docs.scaffoldeth.io/components/): Collection of common web3 components to quickly build your frontend.
- 🔥 **Burner Wallet & Local Faucet**: Quickly test your application with a burner wallet and local faucet.
- 🔐 **Integration with Wallet Providers**: Connect to different wallet providers and interact with the Ethereum network.

![Debug Contracts tab](https://github.com/scaffold-eth/scaffold-eth-2/assets/55535804/b237af0c-5027-4849-a5c1-2e31495cccb1)

## Requirements

Before you begin, you need to install the following tools:

- [Node (>= v20.18.3)](https://nodejs.org/en/download/)
- Yarn ([v1](https://classic.yarnpkg.com/en/docs/install/) or [v2+](https://yarnpkg.com/getting-started/install))
- [Git](https://git-scm.com/downloads)

## Quickstart

To get started with Scaffold-ETH 2, follow the steps below:

1. Install dependencies if it was skipped in CLI:

```
cd my-dapp-example
yarn install
```

2. Run a local network in the first terminal:

```
yarn chain
```

This command starts a local Ethereum network using Foundry. The network runs on your local machine and can be used for testing and development. You can customize the network configuration in `packages/foundry/foundry.toml`.

3. On a second terminal, deploy the test contract:

```
yarn deploy
```

This command deploys a test smart contract to the local network. The contract is located in `packages/foundry/contracts` and can be modified to suit your needs. The `yarn deploy` command uses the deploy script located in `packages/foundry/script` to deploy the contract to the network. You can also customize the deploy script.

4. On a third terminal, start your NextJS app:

```
yarn start
```

Visit your app on: `http://localhost:3000`. You can interact with your smart contract using the `Debug Contracts` page. You can tweak the app config in `packages/nextjs/scaffold.config.ts`.

Run smart contract test with `yarn foundry:test`

- Edit your smart contracts in `packages/foundry/contracts`
- Edit your frontend homepage at `packages/nextjs/app/page.tsx`. For guidance on [routing](https://nextjs.org/docs/app/building-your-application/routing/defining-routes) and configuring [pages/layouts](https://nextjs.org/docs/app/building-your-application/routing/pages-and-layouts) checkout the Next.js documentation.
- Edit your deployment scripts in `packages/foundry/script`


## Documentation

Visit our [docs](https://docs.scaffoldeth.io) to learn how to start building with Scaffold-ETH 2.

To know more about its features, check out our [website](https://scaffoldeth.io).

## Contributing to Scaffold-ETH 2

We welcome contributions to Scaffold-ETH 2!

Please see [CONTRIBUTING.MD](https://github.com/scaffold-eth/scaffold-eth-2/blob/main/CONTRIBUTING.md) for more information and guidelines for contributing to Scaffold-ETH 2.
