const Voting = artifacts.require('Voting');
const MiniMeToken = artifacts.require('MiniMeToken');
const DAOFactory = artifacts.require('DAOFactory');
const EVMScriptRegistryFactory = artifacts.require('EVMScriptRegistryFactory');
const ACL = artifacts.require('ACL');
const Kernel = artifacts.require('Kernel');

const getContract = name => artifacts.require(name);
const pct16 = x => new web3.BigNumber(x).times(new web3.BigNumber(10).toPower(16))

const ANY_ADDR = '0xffffffffffffffffffffffffffffffffffffffff';


contract('Voting App', accounts => {
	let daoFact, app, token, executionTarget = {};

	const votingTime = 1000;
	const root = accounts[0];

	before(async () => {
		const kernelBase = await getContract('Kernel').new();
		const aclBase = await getContract('ACL').new();
		const regFact = await EVMScriptRegistryFactory.new();
		daoFact = await DAOFactory.new(kernelBase.address, aclBase.address, regFact.address)
	});

	beforeEach(async () => {
		const r = await daoFact.newDAO(root)
		const dao = Kernel.at(r.logs.filter(l => l.event === 'DeployDAO')[0].args.dao)
		const acl = ACL.at(await dao.acl())

		await acl.createPermission(root, dao.address, await dao.APP_MANAGER_ROLE(), root, { from: root })

		const receipt = await dao.newAppInstance('0x1234', (await Voting.new()).address, { from: root })
		app = Voting.at(receipt.logs.filter(l => l.event === 'NewAppProxy')[0].args.proxy)

		await acl.createPermission(ANY_ADDR, app.address, await app.CREATE_VOTES_ROLE(), root, { from: root })
		await acl.createPermission(ANY_ADDR, app.address, await app.MODIFY_QUORUM_ROLE(), root, { from: root })
	})

	context('normal token supply', () => {
		const holder19 = accounts[0];
		const holder31 = accounts[1];
		const holder50 = accounts[2];

		const neededSupport = pct16(50);
		const minimumAcceptanceQuorum = pct16(20);

		beforeEach(async () => {
			const n = '0x00';
			token = await MiniMeToken.new(n, n, 0, 'n', 0, 'n', true); // empty parameters minime

			await token.generateTokens(holder19, 19);
			await token.generateTokens(holder31, 31);
			await token.generateTokens(holder50, 50);

			await app.initialize(token.address, neededSupport, minimumAcceptanceQuorum, votingTime)
		})

	})

})