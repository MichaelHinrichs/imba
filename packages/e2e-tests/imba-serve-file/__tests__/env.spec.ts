import { getEl, isBuild } from '~utils';

test('should render the svg and pass props', async () => {
	if(!isBuild){
		const svg = await getEl("svg")
		const html = await svg.innerHTML()
		expect(html).toMatchSnapshot()
		const title = await svg.getAttribute("title")
		expect(title).toBe('imba is cool')
	}
});
