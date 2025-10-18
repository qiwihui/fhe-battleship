import React, { useState } from 'react';
import Boards from "./components/Boards";
import Game from "./scripts/Game";
import { Display, DisplayWrapper, Buttons, Header, HeaderWrapper, Title } from "./components/styled_components/AppStyles";

// Extend Window interface to include ethereum
declare global {
  interface Window {
    ethereum?: any;
  }
}

const App = () => {
  const ships: number[] = [5, 4, 3, 3, 2];
  const [game, setGame] = useState<Game>(new Game(ships, 10));
  const [display, setDisplay] = useState<string>('Connect wallet to start');
  const [turn, setTurn] = useState<0 | 1>(game.getTurn);
  const [init, setInit] = useState<boolean>(game.getInit);
  const [reset, setReset] = useState<boolean>(false);
  const [walletConnected, setWalletConnected] = useState<boolean>(false);
  const [walletAddress, setWalletAddress] = useState<string>('');

  const updateDisplay = () => {
    if (!walletConnected) {
      setDisplay('Connect wallet to start');
    } else if (!game.getInit) {
      setDisplay('Move/Rotate ships');
    } else if (game.getWinner !== -1) {
      setDisplay(`${game.getPlayer(game.getWinner).getName} won!`);
    } else if (game.getInit) {
      setDisplay(`${game.getCurrentPlayer.getName} turn`);
    }
  }

  const connectWallet = async () => {
    try {
      if (typeof window.ethereum !== 'undefined') {
        const accounts = await window.ethereum.request({
          method: 'eth_requestAccounts'
        });

        if (accounts.length > 0) {
          setWalletAddress(accounts[0]);
          setWalletConnected(true);
          setDisplay('Move/Rotate ships');
        }
      } else {
        setDisplay('Please install MetaMask or another Web3 wallet');
      }
    } catch (error) {
      console.error('Error connecting wallet:', error);
      setDisplay('Failed to connect wallet');
    }
  }

  const disconnectWallet = () => {
    setWalletConnected(false);
    setWalletAddress('');
    setDisplay('Connect wallet to start');
    if (init) {
      restartGame();
    }
  }

  const updateTurn = () => {
    setTurn(game.getTurn);
    updateDisplay();
  }

  const updateInit = () => {
    setInit(game.getInit);
  }

  const initGame = () => {
    game.init();
    updateDisplay();
    updateInit();
    setReset(false);
  }

  const restartGame = async () => {
    setGame(new Game(ships, 10));
    setReset(true);
    setDisplay(walletConnected ? "Move/Rotate ships" : "Connect wallet to start");
    setInit(false);
  }

  return (
    <div className="app">
      <HeaderWrapper>
        <div style={{
          display: 'flex',
          justifyContent: 'space-around',
          alignItems: 'center',
          width: '100%'
        }}>
          <Title>
            <Header>FHE Battleship</Header>
          </Title>
          <div style={{
            display: 'flex',
            alignItems: 'center',
          }}>
            {!walletConnected ? (
              <Buttons>
                <button
                  className="startGame"
                  type="button"
                  onClick={connectWallet}
                >
                  Connect Wallet
                </button>
              </Buttons>
            ) : (
              <>
                <div style={{
                  color: '#666',
                }}>
                  {walletAddress.slice(0, 6)}...{walletAddress.slice(-4)}
                </div>
                <Buttons>
                  <button
                    className="startGame"
                    type="button"
                    onClick={disconnectWallet}
                    style={{
                      backgroundColor: '#666',
                      minWidth: 'auto'
                    }}
                  >
                    Disconnect
                  </button>
                </Buttons>
              </>
            )}
          </div>
        </div>
      </HeaderWrapper>
      <DisplayWrapper>
        <Display>
          <h2 className={"display"}>{display}</h2>
        </Display>
      </DisplayWrapper>
      <Boards game={game} updateTurn={updateTurn} turn={turn} init={init} reset={reset} />
      <Buttons>
        {!walletConnected ? (
          <button className="startGame" type="button" onClick={connectWallet}>
            Connect Wallet
          </button>
        ) : !init ? (
          <>
            <button className="startGame" type="button" onClick={initGame}>
              Start Game
            </button>
          </>
        ) : game.getTurn === 0 || game.getWinner !== -1 ? (
          <>
            <button className="startGame" type="button" onClick={restartGame}>
              Restart Game
            </button>
          </>
        ) : (
          <>
            <button className="startGame disabled" type="button">
              Restart Game
            </button>
          </>
        )}
      </Buttons>
    </div>
  );
}

export default App;
