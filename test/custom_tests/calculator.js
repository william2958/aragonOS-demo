const Calculator = artifacts.require('Calculator');
const MiniMeToken = artifacts.require('MiniMeToken');
const DAOFactory = artifacts.require('DAOFactory');
const EVMScriptRegistryFactory = artifacts.require('EVMScriptRegistryFactory');
const ACL = artifacts.require('ACL');
const Kernel = artifacts.require('Kernel');

const getContract = name => artifacts.require(name);

contract('Calculator App', accounts => {
	let daoFact, app, acl;

	const root = accounts[0];

	before(async () => {
		// Create new instances of the core contracts
		const kernelBase = await getContract('Kernel').new();
		const aclBase = await getContract('ACL').new();
		const regFact = await EVMScriptRegistryFactory.new();
		// Create a new DAOFactory instance
		daoFact = await DAOFactory.new(kernelBase.address, aclBase.address, regFact.address)
	});

	beforeEach(async () => {
		const r = await daoFact.newDAO(root)
		// Get the address of the kernel proxy we need to send all of our requests to
		// dao == kernel
		const dao = Kernel.at(r.logs.filter(l => l.event === 'DeployDAO')[0].args.dao)
		// Get the ACL instance so we can create permissions, etc.
		acl = ACL.at(await dao.acl())

		// Create the permission to allow root to create new apps and connect them to the kernel
		await acl.createPermission(root, dao.address, await dao.APP_MANAGER_ROLE(), root, { from: root })

		// Create the new app instance from root, which has the permission to do so
		const receipt = await dao.newAppInstance('0x1234', (await Calculator.new()).address, { from: root })
		// Set the calculator instance using the app proxy. Basically just finds the right address to send requests to
		app = Calculator.at(receipt.logs.filter(l => l.event === 'NewAppProxy')[0].args.proxy)

		// Create two permissions in the application, one to add numbers and one to remove
		await acl.createPermission(accounts[2], app.address, await app.ADD_NUMBER_ROLE(), accounts[1], { from: root })
		await acl.createPermission(accounts[3], app.address, await app.REMOVE_NUMBER_ROLE(), accounts[1], { from: root })

		// Initialize the application
		await app.initialize();
	})



	it ('Should initialize with value of 0', async() => {
		let value = await app.getNumber();
		assert.equal(value.toNumber(), 0, "The number should have defaulted to 0");
	})

	it ('Should allow accounts[2] to increase the number', async() => {
		await app.add(1, {from: accounts[2]});
		let value = await app.getNumber();
		assert.equal(value.toNumber(), 1, "The number should be 1 now");
	})

	it ('Should fail to let accounts[3] to increase the number', async() => {
		await app.add(1, {from: accounts[3]})
			.then(assert.fail)
			.catch(function(error) {
				assert(error.message.indexOf('revert') >= 0, "error should be revert");
			})
	})

	// Grants permission to accounts[4] from accounts[1]. Accounts[1] is able to do this because it is the manager of that role.
	it ('Should allow accounts[1] to grant permission to increase number to accounts[4]', async() => {
		await acl.grantPermission(accounts[4], app.address, await app.ADD_NUMBER_ROLE(), {from: accounts[1]})
		await app.add(1, {from: accounts[4]});
		let value = await app.getNumber();
		assert.equal(value.toNumber(), 1, "The number should be 1 now");
	})

})