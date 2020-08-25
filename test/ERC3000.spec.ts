import {expect, use} from 'chai';
import {Contract, BigNumber} from 'ethers';
import {deployContract, MockProvider, solidity} from 'ethereum-waffle';
import Stake from '../build/ProveOfStake.json'
import ERC3000 from '../build/ERC3000Impl.json'
import { BigNumber as BN } from 'bignumber.js'

use(solidity);

function convertBigNumber(bnAmount: BigNumber, divider: number) {
	return new BN(bnAmount.toString()).dividedBy(new BN(divider)).toFixed();
}



describe('Stake', () => {
	let provider = new MockProvider();
	const [walletMe, walletOther] = provider.getWallets();
	let ERC3000Contract 	: Contract;
	let StakeContract 		: Contract;

	async function ouputAmount(title: string, address : any) {
		let ret = await ERC3000Contract.connect(address).takeWithBlock();
		console.log(title + ' ' + convertBigNumber(ret[0], 1e18) + '@' + ret[1]);
	}

	async function outputProduct(title:string, arr : Array<any>)
	{
		for(let i = 0; i < arr.length; i ++)
		{
			console.log(title, i, convertBigNumber(arr[i],1));
		}
	}

	before(async () => {
		// deployment of ERC3000 token, with input token name, token symbol token decimals, and initial interests produced per block.
		ERC3000Contract = await deployContract(walletMe, ERC3000, ['ERC3000', 'ERC3000', 18, 100]);

		// deployment of Prove of Stake contract, with the input of deployed ERC3000's token contract address.
		StakeContract = await deployContract(walletMe, Stake, [ERC3000Contract.address]);

		// update the ERC3000's implementation to StakeContract just deployed.
		await ERC3000Contract.connect(walletMe).upgradeImpl(StakeContract.address);
		
		console.log('walletMe = ', walletMe.address);
		console.log('walletOther = ', walletOther.address);
		console.log('ERC3000 address = ', ERC3000Contract.address);
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
		await ERC3000Contract.connect(walletMe).mint();
		await ouputAmount('Me', walletMe.address);
		await ouputAmount('Other', walletOther.address);
		console.log(convertBigNumber(await ERC3000Contract.connect(walletMe).balanceOf(walletMe.address), 1e18));
	});
});