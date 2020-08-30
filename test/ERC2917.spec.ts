import {expect, use} from 'chai';
import {Contract, BigNumber} from 'ethers';
import {deployContract, MockProvider, solidity} from 'ethereum-waffle';
import Stake from '../build/ProveOfStake.json'
import ERC2917 from '../build/ERC2917Impl.json'
import { BigNumber as BN } from 'bignumber.js'

use(solidity);

function convertBigNumber(bnAmount: BigNumber, divider: number) {
	return new BN(bnAmount.toString()).dividedBy(new BN(divider)).toFixed();
}

describe('Stake', () => {
	let provider = new MockProvider();
	const [walletMe, walletOther] = provider.getWallets();
	let ERC2917Contract 	: Contract;
	let StakeContract 		: Contract;

	async function ouputAmount(title: string, address : any) {
		let ret = await ERC2917Contract.connect(address).takeWithBlock();
		console.log(title + ' ' + convertBigNumber(ret[0], 1e18) + '@' + ret[1]);
	}

	before(async () => {
		// deployment of ERC2917 token, with input token name, token symbol token decimals, and initial interests produced per block.
		ERC2917Contract = await deployContract(walletMe, ERC2917, ['ERC2917', 'ERC2917', 18, 100]);

		// deployment of Prove of Stake contract, with the input of deployed ERC2917's token contract address.
		StakeContract = await deployContract(walletMe, Stake, [ERC2917Contract.address]);

		// update the ERC2917's implementation to StakeContract just deployed.
		await ERC2917Contract.connect(walletMe).upgradeImpl(StakeContract.address);
		
		console.log('walletMe = ', walletMe.address);
		console.log('walletOther = ', walletOther.address);
		console.log('ERC2917 address = ', ERC2917Contract.address);
		console.log('Stake address = ', StakeContract.address);
	});

	it('Stake', async () => {
		await StakeContract.connect(walletMe).stake({value:100});
		await StakeContract.connect(walletOther).stake({value:100});
		await StakeContract.incNounce();
		await StakeContract.incNounce();
		await StakeContract.incNounce();
		await StakeContract.incNounce();
		await StakeContract.incNounce();
		await StakeContract.incNounce();
		await ouputAmount('Me', walletMe.address);
		await ouputAmount('Other', walletOther.address);

		await StakeContract.connect(walletMe).unstake(100);
		await ouputAmount('Me', walletMe.address);
		await ouputAmount('Other', walletOther.address);
		await ERC2917Contract.connect(walletMe).mint();
		await ouputAmount('Me', walletMe.address);
		await ouputAmount('Other', walletOther.address);
		console.log(convertBigNumber(await ERC2917Contract.connect(walletMe).balanceOf(walletMe.address), 1e18));
	});
});
