package com.bgylde.live.danmaku.flame.parser.android;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.net.URL;

import com.bgylde.live.danmaku.flame.parser.IDataSource;
import com.bgylde.live.danmaku.flame.util.IOUtils;

import org.json.JSONArray;
import org.json.JSONException;

import android.net.Uri;
import android.text.TextUtils;

/**
 * a json file source
 * @author yrom
 */
public class JSONSource implements IDataSource<JSONArray> {
	private JSONArray mJSONArray;
	private InputStream mInput;
	public JSONSource(String json) throws JSONException{
		init(json);
	}
	
	public JSONSource(InputStream in) throws JSONException{
		init(in);
	}
	
	private void init(InputStream in) throws JSONException {
		if(in == null)
			throw new NullPointerException("input stream cannot be null!");
		mInput = in;
		String json = IOUtils.getString(mInput);
		init(json);
	}
	
	public JSONSource(URL url) throws JSONException, IOException{
		this(url.openStream());
	}
	
	public JSONSource(File file) throws FileNotFoundException, JSONException{
		init(new FileInputStream(file));
	}
	
	public JSONSource(Uri uri) throws IOException, JSONException {
		String scheme = uri.getScheme();
        if (SCHEME_HTTP_TAG.equalsIgnoreCase(scheme) || SCHEME_HTTPS_TAG.equalsIgnoreCase(scheme)) {
            init(new URL(uri.getPath()).openStream());
        } else if (SCHEME_FILE_TAG.equalsIgnoreCase(scheme)) {
            init(new FileInputStream(uri.getPath()));
        }
	}
	
	private void init(String json) throws JSONException {
		if(!TextUtils.isEmpty(json)){
			mJSONArray = new JSONArray(json);
		}
	}
    public JSONArray data(){
    	return mJSONArray;
    }

	@Override
	public void release() {
		IOUtils.closeQuietly(mInput);
		mInput = null;
		mJSONArray = null;
	}

}
