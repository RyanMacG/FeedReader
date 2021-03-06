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

public class FeedReader.localUtils : GLib.Object {

	public Logger m_logger { get; construct set; }

	public localUtils(Logger logger)
	{
		m_logger = logger;
	}

	public feed? downloadFeed(string xmlURL, string feedID, string[] catIDs)
	{
		try
		{
			// download
			var session = new Soup.Session();
	        session.timeout = 5;
	        var msg = new Soup.Message("GET", xmlURL.escape(""));
			session.send_message(msg);
			string xml = (string)msg.response_body.flatten().data;

			// parse
			Rss.Parser parser = new Rss.Parser();
			parser.load_from_data(xml, xml.length);
			var doc = parser.get_document();

			downloadIcon(feedID, doc.image_url);

			var Feed = new feed(
						feedID,
						doc.title,
						doc.link,
						true,
						0,
						catIDs,
						xmlURL);

			return Feed;
		}
		catch(GLib.Error e)
		{
			m_logger.print(LogMessage.ERROR, "localInterface - addFeed: " + e.message);
		}

		return null;
	}

	public string? convert(string? text, string locale)
	{
		if(text == null)
			return null;

		try
		{
			return GLib.convert(text, -1, "utf-8", locale);
		}
		catch(ConvertError e)
		{
			m_logger.print(LogMessage.ERROR, e.message);
		}

		return "";
	}

	public bool deleteIcon(string feedID)
	{
		try
		{
			string icon_path = GLib.Environment.get_home_dir() + "/.local/share/feedreader/data/feed_icons/";
			var file = GLib.File.new_for_path(icon_path + feedID + ".ico");
			file.delete();
			return true;
		}
		catch(GLib.Error e)
		{
			m_logger.print(LogMessage.ERROR, "localUtils - deleteIcon: " + e.message);
		}
		return false;
	}

	private bool downloadIcon(string feed_id, string icon_url)
	{
		var settingsTweaks = new GLib.Settings("org.gnome.feedreader.tweaks");
		string icon_path = GLib.Environment.get_home_dir() + "/.local/share/feedreader/data/feed_icons/";
		var path = GLib.File.new_for_path(icon_path);
		try{
			path.make_directory_with_parents();
		}
		catch(GLib.Error e){
			//m_logger.print(LogMessage.DEBUG, e.message);
		}

		string local_filename = icon_path + feed_id + ".ico";

		if(!FileUtils.test(local_filename, GLib.FileTest.EXISTS))
		{
			Soup.Message message_dlIcon;
			message_dlIcon = new Soup.Message("GET", icon_url);

			if(settingsTweaks.get_boolean("do-not-track"))
				message_dlIcon.request_headers.append("DNT", "1");

			var session = new Soup.Session();
			session.ssl_strict = false;
			var status = session.send_message(message_dlIcon);
			if(status == 200)
			{
				try{
					FileUtils.set_contents(	local_filename,
											(string)message_dlIcon.response_body.flatten().data,
											(long)message_dlIcon.response_body.length);
				}
				catch(GLib.FileError e)
				{
					m_logger.print(LogMessage.ERROR, "Error writing icon: %s".printf(e.message));
				}
				return true;
			}
			m_logger.print(LogMessage.ERROR, "Error downloading icon for feed: %s".printf(feed_id));
			return false;
		}

		// file already exists
		return true;
	}
}
