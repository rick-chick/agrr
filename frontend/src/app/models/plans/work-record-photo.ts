export interface WorkRecordPhoto {
  id: number;
  work_record_id: number;
  position: number;
  content_type: string | null;
  byte_size: number | null;
  url: string;
  created_at: string;
}

export interface WorkRecordPhotoUploadInitResponse {
  photo: {
    id: number;
    upload_url: string;
    upload_method: string;
    upload_expires_at: string;
    content_type: string;
  };
}

export interface WorkRecordPhotoCompleteResponse {
  photo: WorkRecordPhoto;
}
