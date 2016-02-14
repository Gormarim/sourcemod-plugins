
enum EventType
{
	EventType_Gamemode = 0,
	EventType_Event
};

methodmap StringProp < ArrayList
{
	public StringProp(char[] str)
	{
		ArrayList t_str = new ArrayList(MAX_STR_LEN, 1);
		t_str.SetString(0, str);
		return view_as<StringProp>(t_str);
	}
	
	public void Set(char[] str)
	{
		this.SetString(0, str);
	}
	
	public void Get(char[] buffer, int maxLen)
	{
		this.GetString(0, buffer, maxLen);
	}
}
	
methodmap BBEvent < ArrayList
{
	public BBEvent(Handle plugin, EventType type, int id)
	{
		ArrayList ev = new ArrayList(1, 9);
		
		ev.Set(0, plugin); // Plugin
		ev.Set(1, type);   // Type
		ev.Set(2, id);     // Id
		ev.Set(3, false);  // Active
		
		ev.Set(4, INVALID_HANDLE); // Name
		ev.Set(5, INVALID_HANDLE); // StartCmd	
		ev.Set(6, INVALID_HANDLE); // InfoCmd
			
		ev.Set(7, INVALID_HANDLE); // ConVars
		ev.Set(8, INVALID_HANDLE); // ConVarsMenu
		
		return view_as<BBEvent>(ev);
	}
	
	property Handle Plugin
	{
		public get()
		{ 
			return this.Get(0);
		}	
	}
	property EventType Type
	{
		public get()
		{ 
			return this.Get(1); 
		}
	}
	property int Id
	{
		public get()
		{ 
			return this.Get(2); 
		}
	}
	property bool Active
	{
		public get()
		{ 
			return this.Get(3); 
		}
		public set(bool status)
		{ 
			this.Set(3, status); 
		}
	}
	property StringProp Name
	{
		public get()
		{ 
			return this.Get(4); 
		}
		public set(StringProp str)
		{
			this.Set(4, str);
		}
	}
	property StringProp MainCmd
	{
		public get()
		{ 
			return this.Get(5); 
		}
		public set(StringProp str)
		{
			this.Set(5, str);
		}
	}
	property StringProp InfoCmd
	{
		public get()
		{ 
			return this.Get(6); 
		}
		public set(StringProp str)
		{
			this.Set(6, str);
		}
	}
	property ArrayList ConVars
	{
		public get()
		{ 
			return this.Get(7); 
		}
		public set(ArrayList list)
		{
			this.Set(7, list);
		}
	}
	property Menu ConVarsMenu
	{
		public get()
		{ 
			return this.Get(8); 
		}
		public set(Menu menu)
		{ 
			this.Set(8, menu); 
		}
	}
}

methodmap PluginData < ArrayList
{
	public PluginData(Handle plugin)
	{
		ArrayList pd = new ArrayList(1, 5);
		pd.Set(0, plugin);
		pd.Set(1, new ArrayList());
		pd.Set(2, new StringMap());
		pd.Set(3, false);
		pd.Set(4, 0);
		
		return view_as<PluginData>(pd);
	}
	
	property Handle Plugin
	{
		public get()
		{ 
			return this.Get(0); 
		}
	}
	property ArrayList EventsList
	{
		public get()
		{ 
			return this.Get(1); 
		}
	}
	property StringMap EventsMap
	{
		public get()
		{ 
			return this.Get(2); 
		}
	}
	property bool Status
	{
		public get()
		{ 
			return this.Get(3); 
		}
		public set(bool status)
		{
			this.Set(3, status);
		}
	}
	property int CurrentId
	{
		public get()
		{ 
			return this.Get(4); 
		}
		public set(int id)
		{
			this.Set(4, id);
		}
	}
}
