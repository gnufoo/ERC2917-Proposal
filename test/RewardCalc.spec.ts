import {expect, use} from 'chai';
import {Contract, BigNumber} from 'ethers';
import {deployContract, MockProvider, solidity} from 'ethereum-waffle';
import Stake from '../build/ProveOfStake.json'
import RewardCalc from '../build/RewardCalcImpl.json'
import { BigNumber as BN } from 'bignumber.js'

use(solidity);

function convertBigNumber(bnAmount: BigNumber, divider: number) {
	return new BN(bnAmount.toString()).dividedBy(new BN(divider)).toFixed();
}

describe('Stake', () => {
	let provider = new MockProvider();
	const [walletMe, walletOther] = provider.getWallets();
	let RewardCalcContract 	: Contract;
	let StakeContract 		: Contract;

	async function ouputAmount(title: string, address : any) {
		let ret = await RewardCalcContract.connect(address).takeWithBlock();
		console.log(title + ' ' + convertBigNumber(ret[0], 1e18) + '@' + ret[1]);
	}

	before(async () => {
		// deployment of RewardCalc token, with input token name, token symbol token decimals, and initial interests produced per block.
		RewardCalcContract = await deployContract(walletMe, RewardCalc, ['RewardCalc', 'RewardCalc', 18, 100]);

		// deployment of Prove of Stake contract, with the input of deployed RewardCalc's token contract address.
		StakeContract = await deployContract(walletMe, Stake, [RewardCalcContract.address]);

		// update the RewardCalc's implementation to StakeContract just deployed.
		await RewardCalcContract.connect(walletMe).upgradeImpl(StakeContract.address);
		
		console.log('walletMe = ', walletMe.address);
		console.log('walletOther = ', walletOther.address);
		console.log('RewardCalc address = ', RewardCalcContract.address);
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
		await RewardCalcContract.connect(walletMe).mint();
		await ouputAmount('Me', walletMe.address);
		await ouputAmount('Other', walletOther.address);
		console.log(convertBigNumber(await RewardCalcContract.connect(walletMe).balanceOf(walletMe.address), 1e18));
	});
});
