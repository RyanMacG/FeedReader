//	This file is part of FeedReader.
//
//	FeedReader is free software: you can redistribute it and/or modify
//	it under the terms of the GNU General Public License as published by
//	the Free Software Foundation, either version 3 of the License, or
//	(at your option) any later version.
//
//	FeedReader is distributed in the hope that it will be useful,
//	but WITHOUT ANY WARRANTY; without even the implied warranty of
//	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//	GNU General Public License for more details.
//
//	You should have received a copy of the GNU General Public License
//	along with FeedReader.  If not, see <http://www.gnu.org/licenses/>.

public class FeedReader.feedbinUtils : GLib.Object {

	GLib.Settings m_settings;

	public feedbinUtils()
	{
		m_settings = new GLib.Settings("org.gnome.feedreader.feedbin");
	}

	public string getUser()
	{
		return m_settings.get_string("username");
	}

	public void setUser(string user)
	{
		m_settings.set_string("username", user);
	}

	public string getPasswd()
	{
		var pwSchema = new Secret.Schema ("org.gnome.feedreader.password", Secret.SchemaFlags.NONE,
		                                  "URL", Secret.SchemaAttributeType.STRING,
		                                  "Username", Secret.SchemaAttributeType.STRING);

		var attributes = new GLib.HashTable<string,string>(str_hash, str_equal);
		attributes["URL"] = "feedbin.com";
		attributes["Username"] = getUser();

		string passwd = "";

		try{
			passwd = Secret.password_lookupv_sync(pwSchema, attributes, null);
		}
		catch(GLib.Error e){
			logger.print(LogMessage.ERROR, e.message);
		}

		if(passwd == null)
		{
			return "";
		}

		return passwd;
	}

	public void setPassword(string passwd)
	{
		var pwSchema = new Secret.Schema ("org.gnome.feedreader.password", Secret.SchemaFlags.NONE,
										  "URL", Secret.SchemaAttributeType.STRING,
										  "Username", Secret.SchemaAttributeType.STRING);
		var attributes = new GLib.HashTable<string,string>(str_hash, str_equal);
		attributes["URL"] = "feedbin.com";
		attributes["Username"] = getUser();
		try
		{
			Secret.password_storev_sync(pwSchema, attributes, Secret.COLLECTION_DEFAULT, "Feedserver login", passwd, null);
		}
		catch(GLib.Error e)
		{
			logger.print(LogMessage.ERROR, "feedbinUtils: setPassword: " + e.message);
		}
	}

	public void resetAccount()
	{
		Utils.resetSettings(m_settings);
		deletePassword();
	}

	public bool deletePassword()
	{
		bool removed = false;
		var pwSchema = new Secret.Schema ("org.gnome.feedreader.password", Secret.SchemaFlags.NONE,
										"URL", Secret.SchemaAttributeType.STRING,
										"Username", Secret.SchemaAttributeType.STRING);
		var attributes = new GLib.HashTable<string,string>(str_hash, str_equal);
		attributes["URL"] = "feedbin.com";
		attributes["Username"] = getUser();

		Secret.password_clearv.begin (pwSchema, attributes, null, (obj, async_res) => {
			removed = Secret.password_clearv.end(async_res);
		});
		return removed;
	}

	public string? catExists(Gee.LinkedList<category> categories, string name)
	{
		foreach(category cat in categories)
		{
			if(cat.getTitle() == name)
				return cat.getCatID();
		}

		return null;
	}

	public void addFeedToCat(Gee.LinkedList<feed> feeds, string feedID, string catID)
	{
		foreach(feed f in feeds)
		{
			if(f.getFeedID() == feedID)
			{
				f.setCats( {catID} );
			}
		}
	}

	public bool isIDinArray(string[] arrayID, string id)
	{
		foreach(string i in arrayID)
		{
			if(i == id)
				return true;
		}

		return false;
	}

	public bool downloadIcon(string feed_id, string feed_url)
	{
		var settingsTweaks = new GLib.Settings("org.gnome.feedreader.tweaks");
		string icon_path = GLib.Environment.get_home_dir() + "/.local/share/feedreader/data/feed_icons/";
		var path = GLib.File.new_for_path(icon_path);
		try{path.make_directory_with_parents();}catch(GLib.Error e){}
		string local_filename = icon_path + feed_id.replace("/", "_").replace(".", "_") + ".ico";

		string url = feed_url;
		if(feed_url.has_prefix("http://"))
			url.replace("http://", "");
		else if(feed_url.has_prefix("https://"))
			url.replace("https://", "");

		if(!FileUtils.test(local_filename, GLib.FileTest.EXISTS))
		{
			Soup.Message message_dlIcon;
			message_dlIcon = new Soup.Message ("GET", "http://f1.allesedv.com/32/%s".printf(url));

			if(settingsTweaks.get_boolean("do-not-track"))
				message_dlIcon.request_headers.append("DNT", "1");

			var session = new Soup.Session ();
			var status = session.send_message(message_dlIcon);
			if (status == 200)
			{
				try{
					FileUtils.set_contents(local_filename, (string)message_dlIcon.response_body.flatten().data, (long)message_dlIcon.response_body.length);
				}
				catch(GLib.FileError e)
				{
					logger.print(LogMessage.ERROR, "Error writing icon: %s".printf(e.message));
				}
				return true;
			}
			logger.print(LogMessage.ERROR, "Error downloading icon for feed: %s".printf(feed_id));
			return false;
		}
		// file already exists
		return true;
	}
}
